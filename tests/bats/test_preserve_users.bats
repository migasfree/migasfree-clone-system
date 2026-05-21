load '../helpers/assert'

setup() {
    load '../helpers/mocks'
    setup_mocks
    source_functions

    # Temporary directory for test files
    TEST_TMP_DIR=$(mktemp -d)

    # Setup old system mock folder structure
    OLD_SYSTEM_DIR="${TEST_TMP_DIR}/old_system"
    mkdir -p "${OLD_SYSTEM_DIR}/etc"

    # Setup new system mock folder structure
    NEW_SYSTEM_DIR="${TEST_TMP_DIR}/new_system"
    mkdir -p "${NEW_SYSTEM_DIR}/etc"

    # Create original passwd, shadow, group, gshadow backup mock database
    cat <<EOF > "${OLD_SYSTEM_DIR}/etc/passwd"
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/:/sbin/nologin
alberto:x:1000:1000:Alberto:/home/alberto:/bin/bash
mateo:x:1001:1001:Mateo:/home/mateo:/bin/bash
EOF

    cat <<EOF > "${OLD_SYSTEM_DIR}/etc/shadow"
root:\$6\$rootpwdold:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
alberto:\$6\$albertopwdold:19000:0:99999:7:::
mateo:\$6\$mateopwdold:19000:0:99999:7:::
EOF

    cat <<EOF > "${OLD_SYSTEM_DIR}/etc/group"
root:x:0:
sudo:x:27:alberto
wheel:x:10:alberto,mateo
nogroup:x:65534:
alberto:x:1000:
mateo:x:1001:
customgroup:x:1005:alberto
EOF

    cat <<EOF > "${OLD_SYSTEM_DIR}/etc/gshadow"
root:*::
sudo:*::alberto
wheel:*::alberto,mateo
nogroup:*::
alberto:*::
mateo:*::
customgroup:*::alberto
EOF

    # Create new system base passwd, shadow, group, gshadow with conflicting UID/GID entries
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/passwd"
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/:/sbin/nologin
conflict_user:x:1000:1000:Conflict User:/home/conflict:/bin/bash
EOF

    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/shadow"
root:\$6\$rootpwdnew:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
conflict_user:\$6\$conflictpwd:19000:0:99999:7:::
EOF

    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/group"
root:x:0:
sudo:x:27:
wheel:x:10:
nogroup:x:65534:
conflict_group:x:1000:
EOF

    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/gshadow"
root:*::
sudo:*::
wheel:*::
nogroup:*::
conflict_group:*::
EOF
}

teardown() {
    teardown_mocks
    rm -rf "$TEST_TMP_DIR"
    rm -rf /tmp/mcs_user_backup
}

@test "add_user_to_group: correctly appends user to empty and non-empty groups" {
    local GROUP_FILE="${TEST_TMP_DIR}/test_group"
    local GSHADOW_FILE="${TEST_TMP_DIR}/test_gshadow"

    echo "sudo:x:27:" > "$GROUP_FILE"
    echo "wheel:x:10:alberto" >> "$GROUP_FILE"
    echo "sudo:*::" > "$GSHADOW_FILE"
    echo "wheel:*::alberto" >> "$GSHADOW_FILE"

    run add_user_to_group "mateo" "sudo" "$GROUP_FILE"
    assert_success
    run add_user_to_group "mateo" "sudo" "$GSHADOW_FILE"
    assert_success

    run add_user_to_group "mateo" "wheel" "$GROUP_FILE"
    assert_success
    run add_user_to_group "mateo" "wheel" "$GSHADOW_FILE"
    assert_success

    # Verify sudo has only mateo
    run grep "^sudo:" "$GROUP_FILE"
    assert_output_contains "sudo:x:27:mateo"
    run grep "^sudo:" "$GSHADOW_FILE"
    assert_output_contains "sudo:*::mateo"

    # Verify wheel has both alberto and mateo
    run grep "^wheel:" "$GROUP_FILE"
    assert_output_contains "wheel:x:10:alberto,mateo"
    run grep "^wheel:" "$GSHADOW_FILE"
    assert_output_contains "wheel:*::alberto,mateo"
}

@test "backup_local_users: mounts target partition and copies files" {
    # Redefine part_by_name and mount for testing backup
    part_by_name() {
        echo "${TEST_TMP_DIR}/mock_sys_part"
    }

    mount() {
        # Simulate copying from old system to /tmp/mnt_old_system
        local mount_dir="${@: -1}"
        mkdir -p "${mount_dir}/etc"
        cp "${OLD_SYSTEM_DIR}/etc"/* "${mount_dir}/etc/"
        return 0
    }

    touch "${TEST_TMP_DIR}/mock_sys_part"
    run backup_local_users "/dev/sda"
    assert_success

    # Verify backup directories exist and have copied content
    [ -f "/tmp/mcs_user_backup/passwd" ]
    [ -f "/tmp/mcs_user_backup/shadow" ]
    [ -f "/tmp/mcs_user_backup/group" ]
    [ -f "/tmp/mcs_user_backup/gshadow" ]

    run grep "^alberto:" "/tmp/mcs_user_backup/passwd"
    assert_success
}

@test "restore_local_users: merges standard users but protects UID 1000 unconditionally" {
    # Directly populate backup folder with a standard user occupying UID 1000 (no tag)
    mkdir -p /tmp/mcs_user_backup
    cp "${OLD_SYSTEM_DIR}/etc"/* /tmp/mcs_user_backup/

    run restore_local_users "${NEW_SYSTEM_DIR}"
    assert_success

    # The target's native UID 1000 ('conflict_user') must be preserved
    run grep "^conflict_user:" "${NEW_SYSTEM_DIR}/etc/passwd"
    assert_output_contains "conflict_user:x:1000:1000"

    # Backup user 'alberto' (UID 1000) must NOT be restored
    run grep "^alberto:" "${NEW_SYSTEM_DIR}/etc/passwd"
    assert_failure
}

@test "restore_local_users: succeeds and skips admin when backup admin has MIGASFREE-ADMIN tag" {
    # Add MIGASFREE-ADMIN tag to the UID 1000 user in both backup passwd and group
    cat <<EOF > "${OLD_SYSTEM_DIR}/etc/passwd"
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/:/sbin/nologin
alberto:x:1000:1000:Alberto,MIGASFREE-ADMIN,,:/home/alberto:/bin/bash
mateo:x:1001:1001:Mateo:/home/mateo:/bin/bash
EOF

    # Prepare backup folder
    mkdir -p /tmp/mcs_user_backup
    cp "${OLD_SYSTEM_DIR}/etc"/* /tmp/mcs_user_backup/

    # Setup the MGI target passwd with the master admin user tagged
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/passwd"
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/:/sbin/nologin
acme-admin:x:1000:1000:ACME Admin,MIGASFREE-ADMIN,,:/home/acme-admin:/bin/bash
EOF
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/shadow"
root:\$6\$rootpwdnew:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
acme-admin:\$6\$masteradminpwd:19000:0:99999:7:::
EOF

    run restore_local_users "${NEW_SYSTEM_DIR}"
    assert_success

    # Assert standard user mateo is restored
    run grep "^mateo:" "${NEW_SYSTEM_DIR}/etc/passwd"
    assert_output_contains "mateo:x:1001:1001:Mateo:/home/mateo:/bin/bash"

    # Assert centralized admin acme-admin was skipped (retaining master credentials)
    run grep "^acme-admin:" "${NEW_SYSTEM_DIR}/etc/passwd"
    assert_output_contains "acme-admin:x:1000:1000:ACME Admin,MIGASFREE-ADMIN"
    run grep "^acme-admin:" "${NEW_SYSTEM_DIR}/etc/shadow"
    assert_output_contains "\$6\$masteradminpwd"

    # Assert backup alberto was NOT restored (skipped to avoid conflict with admin)
    run grep "^alberto:" "${NEW_SYSTEM_DIR}/etc/passwd"
    assert_failure

    # Assert permissions are strictly set
    [ -f "${NEW_SYSTEM_DIR}/etc/passwd" ]
    [ -f "${NEW_SYSTEM_DIR}/etc/shadow" ]
}

@test "check_local_users_safety: returns success when no SYSTEM partition exists" {
    # Mock part_by_label_on_device to return empty (simulating fresh/blank disk)
    part_by_label_on_device() {
        echo ""
    }

    run check_local_users_safety "/dev/sda"
    assert_success
}

@test "check_local_users_safety: returns success when UID 1000 has MIGASFREE-ADMIN tag" {
    part_by_label_on_device() {
        echo "/dev/sda3"
    }

    # Simulate mounted partition contents in the mock safety mount path
    mkdir -p "/tmp/mcs_safety_mount/etc"
    cat <<EOF > "/tmp/mcs_safety_mount/etc/passwd"
root:x:0:0:root:/root:/bin/bash
acme-admin:x:1000:1000:ACME Admin,MIGASFREE-ADMIN,,:/home/acme-admin:/bin/bash
EOF

    run check_local_users_safety "/dev/sda"
    assert_success

    rm -rf "/tmp/mcs_safety_mount"
}

@test "check_local_users_safety: returns failure when standard user occupies UID 1000" {
    part_by_label_on_device() {
        echo "/dev/sda3"
    }

    # Simulate mounted partition contents with non-admin occupying UID 1000
    mkdir -p "/tmp/mcs_safety_mount/etc"
    cat <<EOF > "/tmp/mcs_safety_mount/etc/passwd"
root:x:0:0:root:/root:/bin/bash
alberto:x:1000:1000:Alberto:/home/alberto:/bin/bash
EOF

    run check_local_users_safety "/dev/sda"
    assert_failure

    rm -rf "/tmp/mcs_safety_mount"
}

@test "restore_local_users: enforces MGI admin when backup has untagged UID 1000 user" {
    # Backup from old disk: a regular user occupying UID 1000 (no MIGASFREE-ADMIN tag)
    mkdir -p /tmp/mcs_user_backup
    cat <<EOF > /tmp/mcs_user_backup/passwd
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/:/sbin/nologin
alberto:x:1000:1000:Alberto:/home/alberto:/bin/bash
mateo:x:1001:1001:Mateo:/home/mateo:/bin/bash
EOF
    cat <<EOF > /tmp/mcs_user_backup/shadow
root:\$6\$rootpwdold:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
alberto:\$6\$albertopwdold:19000:0:99999:7:::
mateo:\$6\$mateopwdold:19000:0:99999:7:::
EOF
    cat <<EOF > /tmp/mcs_user_backup/group
root:x:0:
alberto:x:1000:
mateo:x:1001:
EOF
    cat <<EOF > /tmp/mcs_user_backup/gshadow
root:*::
alberto:*::
mateo:*::
EOF

    # MGI image target: has its own admin at UID 1000
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/passwd"
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/:/sbin/nologin
acme-admin:x:1000:1000:ACME Admin,MIGASFREE-ADMIN,,:/home/acme-admin:/bin/bash
EOF
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/shadow"
root:\$6\$rootpwdnew:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
acme-admin:\$6\$masteradminpwd:19000:0:99999:7:::
EOF
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/group"
root:x:0:
acme-admin:x:1000:
EOF
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/gshadow"
root:*::
acme-admin:*::
EOF

    run restore_local_users "${NEW_SYSTEM_DIR}"
    assert_success

    # MGI admin must be preserved with original credentials
    run grep "^acme-admin:" "${NEW_SYSTEM_DIR}/etc/passwd"
    assert_output_contains "acme-admin:x:1000:1000:ACME Admin,MIGASFREE-ADMIN"
    run grep "^acme-admin:" "${NEW_SYSTEM_DIR}/etc/shadow"
    assert_output_contains "\$6\$masteradminpwd"

    # Backup user 'alberto' (UID 1000 without tag) must NOT be restored
    run grep "^alberto:" "${NEW_SYSTEM_DIR}/etc/passwd"
    assert_failure

    # Standard user 'mateo' (UID 1001) must be restored normally
    run grep "^mateo:" "${NEW_SYSTEM_DIR}/etc/passwd"
    assert_output_contains "mateo:x:1001:1001:Mateo:/home/mateo:/bin/bash"

    # No duplicate UID 1000 entries
    local uid_1000_count=$(awk -F: '$3 == 1000' "${NEW_SYSTEM_DIR}/etc/passwd" | wc -l)
    [ "$uid_1000_count" -eq 1 ]
}

@test "restore_local_users: protects GID 1000 admin group from backup overwrite" {
    # Backup with a group at GID 1000 named 'alberto'
    mkdir -p /tmp/mcs_user_backup
    cat <<EOF > /tmp/mcs_user_backup/passwd
root:x:0:0:root:/root:/bin/bash
mateo:x:1001:1001:Mateo:/home/mateo:/bin/bash
EOF
    cat <<EOF > /tmp/mcs_user_backup/shadow
root:\$6\$rootpwdold:19000:0:99999:7:::
mateo:\$6\$mateopwdold:19000:0:99999:7:::
EOF
    cat <<EOF > /tmp/mcs_user_backup/group
root:x:0:
alberto:x:1000:
mateo:x:1001:
EOF
    cat <<EOF > /tmp/mcs_user_backup/gshadow
root:*::
alberto:*::
mateo:*::
EOF

    # MGI target with admin group at GID 1000
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/passwd"
root:x:0:0:root:/root:/bin/bash
acme-admin:x:1000:1000:ACME Admin,MIGASFREE-ADMIN,,:/home/acme-admin:/bin/bash
EOF
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/shadow"
root:\$6\$rootpwdnew:19000:0:99999:7:::
acme-admin:\$6\$masteradminpwd:19000:0:99999:7:::
EOF
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/group"
root:x:0:
acme-admin:x:1000:
EOF
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/gshadow"
root:*::
acme-admin:*::
EOF

    run restore_local_users "${NEW_SYSTEM_DIR}"
    assert_success

    # MGI admin group (GID 1000) must NOT be overwritten by backup 'alberto' group
    run grep ":x:1000:" "${NEW_SYSTEM_DIR}/etc/group"
    assert_output_contains "acme-admin"

    # Standard group 'mateo' (GID 1001) must be restored
    run grep "^mateo:" "${NEW_SYSTEM_DIR}/etc/group"
    assert_output_contains "mateo:x:1001:"
}

@test "restore_local_users: deletes old admin user account and home directory when username differs" {
    # Backup has old admin named 'admin' (UID 1000) with home directory '/home/admin'
    mkdir -p /tmp/mcs_user_backup
    cat <<EOF > /tmp/mcs_user_backup/passwd
root:x:0:0:root:/root:/bin/bash
admin:x:1000:1000:Old Admin,MIGASFREE-ADMIN,,:/home/admin:/bin/bash
mateo:x:1001:1001:Mateo:/home/mateo:/bin/bash
EOF
    cat <<EOF > /tmp/mcs_user_backup/shadow
root:\$6\$rootpwdold:19000:0:99999:7:::
admin:\$6\$adminpwdold:19000:0:99999:7:::
mateo:\$6\$mateopwdold:19000:0:99999:7:::
EOF
    cat <<EOF > /tmp/mcs_user_backup/group
root:x:0:
admin:x:1000:
mateo:x:1001:
EOF
    cat <<EOF > /tmp/mcs_user_backup/gshadow
root:*::
admin:*::
mateo:*::
EOF

    # MGI image target has new admin named 'senior' (UID 1000) with home directory '/home/senior'
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/passwd"
root:x:0:0:root:/root:/bin/bash
senior:x:1000:1000:Senior Admin,MIGASFREE-ADMIN,,:/home/senior:/bin/bash
EOF
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/shadow"
root:\$6\$rootpwdnew:19000:0:99999:7:::
senior:\$6\$seniorpwdnew:19000:0:99999:7:::
EOF
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/group"
root:x:0:
senior:x:1000:
EOF
    cat <<EOF > "${NEW_SYSTEM_DIR}/etc/gshadow"
root:*::
senior:*::
EOF

    # Mock the home directories on physical target to simulate preserved home
    mkdir -p "${NEW_SYSTEM_DIR}/home/admin"
    mkdir -p "${NEW_SYSTEM_DIR}/home/senior"

    # We do not pass _DEVICE in test to check file/directory cleanup logic directly on NEW_SYSTEM_DIR
    run restore_local_users "${NEW_SYSTEM_DIR}"
    assert_success

    # The old admin user 'admin' must be deleted from target configuration files
    run grep "^admin:" "${NEW_SYSTEM_DIR}/etc/passwd"
    assert_failure
    run grep "^admin:" "${NEW_SYSTEM_DIR}/etc/shadow"
    assert_failure
    run grep "^admin:" "${NEW_SYSTEM_DIR}/etc/group"
    assert_failure

    # The old admin home directory must be deleted
    [ ! -d "${NEW_SYSTEM_DIR}/home/admin" ]

    # The new admin user 'senior' must be preserved/enforced
    run grep "^senior:" "${NEW_SYSTEM_DIR}/etc/passwd"
    assert_output_contains "senior:x:1000:1000"
    run grep "^senior:" "${NEW_SYSTEM_DIR}/etc/shadow"
    assert_output_contains "\$6\$seniorpwdnew"

    # The new admin home directory must exist
    [ -d "${NEW_SYSTEM_DIR}/home/senior" ]
}


