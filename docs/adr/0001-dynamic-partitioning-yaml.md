# ADR 0001: Dynamic Partitioning via YAML and yq

## Status

Accepted

## Context

Originally, the Migasfree Clone System (MCS) used a hardcoded partition scheme (JSON string) within the shell functions. This made the system rigid, requiring a full ISO rebuild to change the disk layout, and prevented project-specific customizations which are essential for diverse deployment environments (e.g., varying disk sizes, custom data partitions).

## Decision

We decided to transition to a dynamic partitioning engine that:

1. Uses **YAML** (`partition.yml`) as the configuration format due to its readability and wide adoption.
2. Leverages **`yq`** (go implementation) for robust parsing of YAML into JSON for shell processing.
3. Makes the `partition.yml` file **mandatory** for every project to ensure explicit configuration.
4. Implements a consistent naming convention where partition names must match their `.raw` files (e.g., `HOME` -> `HOME.raw`). Legacy fallbacks like `DATA.raw` have been removed.

## Alternatives Considered

- **Direct Bash Variables**: Rejected because complex structures (like partition lists) are hard to maintain and validate in pure shell.
- **SQLite**: Rejected to keep the minimal Alpine image size low and avoid database maintenance.
- **Hardcoded defaults**: Rejected to enforce better project hygiene where every project defines its own requirements.

## Consequences

- **Positive**: High flexibility; projects can now define any GPT layout without rebuilding the ISO.
- **Positive**: Documentation is now the source of truth for disk layouts.
- **Neutral**: Added `yq` and `jq` as critical dependencies in the MCS image.
- **Negative**: Projects without a `partition.yml` will fail to clone, requiring a one-time migration of existing image pools.
