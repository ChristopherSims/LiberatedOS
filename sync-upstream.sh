#!/usr/bin/env bash
# sync-upstream.sh - Synchronize FreeOS with upstream CachyOS and Liberated systemd
# Called by GitHub Actions or can be run manually.
set -euo pipefail

CACHYOS_REMOTE="https://github.com/CachyOS/linux-cachyos.git"
CACHYOS_BRANCH="master"
SYSTEMD_REMOTE="https://github.com/Jeffrey-Sardina/systemd.git"
SYSTEMD_BRANCH="main"

DRY_RUN="${DRY_RUN:-false}"
CHANGES=0

log() { echo "[sync-upstream] $*"; }

# --- CachyOS sync ---
sync_cachyos() {
    log "Checking CachyOS/linux-cachyos for updates..."

    # Fetch latest from CachyOS
    git fetch upstream-cachyos "$CACHYOS_BRANCH" 2>/dev/null || {
        log "Adding CachyOS remote..."
        git remote add upstream-cachyos "$CACHYOS_REMOTE"
        git fetch upstream-cachyos "$CACHYOS_BRANCH"
    }

    LOCAL_HEAD=$(git rev-parse HEAD)
    UPSTREAM_HEAD=$(git rev-parse "upstream-cachyos/$CACHYOS_BRANCH")

    if [ "$LOCAL_HEAD" = "$UPSTREAM_HEAD" ]; then
        # Check if upstream has commits we don't have in our tree
        # We compare by checking merge-base
        MERGE_BASE=$(git merge-base HEAD "upstream-cachyos/$CACHYOS_BRANCH")
        if [ "$MERGE_BASE" = "$UPSTREAM_HEAD" ]; then
            log "CachyOS: No new updates."
            return 0
        fi
    fi

    log "CachyOS has updates. Syncing..."
    CHANGES=1

    if [ "$DRY_RUN" = "true" ]; then
        log "DRY RUN: would merge CachyOS updates"
        return 0
    fi

    # Merge upstream changes, preferring ours for README and branding
    git merge "upstream-cachyos/$CACHYOS_BRANCH" \
        --no-edit \
        -m "sync: merge CachyOS/linux-cachyos upstream updates" || {
        log "Merge conflict detected, resolving with ours strategy for FreeOS files..."

        # Resolve conflicts: prefer upstream for kernel files, ours for branding
        # Accept all upstream changes for kernel directories
        for conflict in $(git diff --name-only --diff-filter=U); do
            case "$conflict" in
                README.md|CODE_OF_CONDUCT.md|CONTRIBUTING.md|.github/FUNDING.yml)
                    git checkout --ours -- "$conflict"
                    git add "$conflict"
                    ;;
                *)
                    git checkout --theirs -- "$conflict"
                    git add "$conflict"
                    ;;
            esac
        done
        git commit --no-edit
    }

    # Replace any systemd/systemd references that may have been introduced
    replace_systemd_refs
}

# --- Liberated systemd sync ---
sync_systemd() {
    log "Checking Jeffrey-Sardina/systemd for updates..."

    git submodule update --init --remote systemd

    SYSTEMD_CURRENT=$(git ls-tree HEAD -- systemd | awk '{print $3}')
    cd systemd
    git fetch origin "$SYSTEMD_BRANCH"
    SYSTEMD_LATEST=$(git rev-parse "origin/$SYSTEMD_BRANCH")
    cd ..

    if [ "$SYSTEMD_CURRENT" = "$SYSTEMD_LATEST" ]; then
        log "Liberated systemd: No new updates."
        return 0
    fi

    log "Liberated systemd has updates. Updating submodule..."
    CHANGES=1

    if [ "$DRY_RUN" = "true" ]; then
        log "DRY RUN: would update systemd submodule"
        return 0
    fi

    cd systemd
    git checkout "$SYSTEMD_LATEST"
    cd ..
    git add systemd
    git commit -m "sync: update Liberated systemd submodule to $SYSTEMD_LATEST" --no-edit || true
}

# --- Replace systemd references ---
replace_systemd_refs() {
    log "Replacing systemd/systemd references with Jeffrey-Sardina/systemd..."

    CHANGED=0
    for pkgbuild in $(find . -name PKGBUILD -not -path "./systemd/*"); do
        if grep -q 'https://github.com/systemd/systemd/' "$pkgbuild" 2>/dev/null; then
            sed -i 's|https://github.com/systemd/systemd/|https://github.com/Jeffrey-Sardina/systemd/|g' "$pkgbuild"
            git add "$pkgbuild"
            CHANGED=1
        fi
    done

    if [ "$CHANGED" = "1" ]; then
        git commit -m "sync: replace systemd/systemd references with Jeffrey-Sardina/systemd" --no-edit || true
    fi
}

# --- Main ---
main() {
    cd "$(git rev-parse --show-toplevel)"

    # Ensure clean working tree
    if [ -n "$(git status --porcelain)" ]; then
        log "Working tree is not clean. Stashing changes..."
        git stash
    fi

    sync_cachyos
    sync_systemd

    if [ "$CHANGES" = "1" ]; then
        log "Updates applied and committed."
    else
        log "No updates found."
    fi

    # Output for GitHub Actions
    echo "has_changes=$CHANGES" >> "$GITHUB_OUTPUT" 2>/dev/null || true
}

main
