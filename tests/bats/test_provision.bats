load '../helpers/assert'
load '../helpers/mocks'

setup() {
    setup_mocks
    source_functions
}

teardown() {
    teardown_mocks
    rm -f /tmp/provision.sh.j2 /tmp/provision_answers.env /tmp/provision_rendered.sh /tmp/mcs_vars.yml /tmp/provision_converted.sh
}

@test "extract_provision_variables: extracts vars and ignores automatic ones" {
    local temp_script="$MOCK_DIR/test_script.sh.j2"
    cat > "$temp_script" <<'EOF'
#!/bin/bash
# --- MCS Variables ---
# variables:
#   hostname:
#     label: "Nombre"
#   static_ip:
#     label: "IP"
# ---
echo "{{ hostname }}"
echo "{{ server }}"
echo "{{ static_ip }}"
echo "{{ project_name }}"
EOF

    run extract_provision_variables "$temp_script"
    assert_success
    assert_output_contains "hostname"
    assert_output_contains "static_ip"
    assert_output_not_contains "server"
    assert_output_not_contains "project_name"
}

@test "extract_provision_variables: preserves YAML indentation structure in mcs_vars.yml" {
    local temp_script="$MOCK_DIR/test_script.sh.j2"
    cat > "$temp_script" <<'EOF'
#!/bin/bash
# --- MCS Variables ---
# variables:
#   hostname:
#     label: "Nombre"
#     default: "default_pc"
#     required: true
# ---
echo "{{ hostname }}"
EOF

    run extract_provision_variables "$temp_script"
    assert_success

    [ -f /tmp/mcs_vars.yml ]

    # Check exact structure and spacing of mcs_vars.yml
    run grep -E '^variables:' /tmp/mcs_vars.yml
    assert_success
    run grep -E '^  hostname:' /tmp/mcs_vars.yml
    assert_success
    run grep -E '^    label: "Nombre"' /tmp/mcs_vars.yml
    assert_success
    run grep -E '^    default: "default_pc"' /tmp/mcs_vars.yml
    assert_success
    run grep -E '^    required: true' /tmp/mcs_vars.yml
    assert_success
}

@test "get_auto_variables: generates correct automatic assignments" {
    export SERVER_URL="migasfree.server.local"
    
    run get_auto_variables "ies-central-v4-flavour1"
    assert_success
    assert_output_contains "server=migasfree.server.local"
    assert_output_contains "project_name=ies"
    assert_output_contains "project_slug=ies"
    assert_output_contains "release=central"
    assert_output_contains "flavour=v4"
}

@test "render_provision_script: substitutes placeholders with env vars safely" {
    local temp_template="$MOCK_DIR/test_template.sh.j2"
    cat > "$temp_template" <<'EOF'
#!/bin/bash
echo "Hello {{ name }}"
echo "Path is $PATH"
echo "Project is {{ project_name }}"
EOF

    local temp_env="$MOCK_DIR/test_vars.env"
    cat > "$temp_env" <<'EOF'
name=Alberto
project_name=myproject
EOF

    local temp_out="$MOCK_DIR/test_output.sh"

    # Make sure envsubst is available or mock it if needed
    if ! command -v envsubst >/dev/null 2>&1; then
        cat > "$MOCK_DIR/envsubst" <<'SCRIPT'
#!/bin/bash
sed "s/\$name/Alberto/g; s/\$project_name/myproject/g"
SCRIPT
        chmod +x "$MOCK_DIR/envsubst"
    fi

    run render_provision_script "$temp_template" "$temp_env" "$temp_out"
    assert_success

    run cat "$temp_out"
    assert_success
    assert_output_contains "Hello Alberto"
    assert_output_contains "Project is myproject"
    assert_output_contains "Path is \$PATH"
}

@test "extract_provision_variables: extracts vars declared in YAML even if not used as placeholders in the script body" {
    local temp_script="$MOCK_DIR/test_script.sh.j2"
    cat > "$temp_script" <<'EOF'
#!/bin/bash
# --- MCS Variables ---
# variables:
#   hostname:
#     label: "Hostname (PCXXXXX)"
#     default: ""
#     required: true
#   miip:
#     label: "miip"
#     default: ""
#     required: true
# ---
echo "No placeholders here"
EOF

    run extract_provision_variables "$temp_script"
    assert_success
    assert_output_contains "hostname"
    assert_output_contains "miip"
}

