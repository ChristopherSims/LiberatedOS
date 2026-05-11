#!/usr/bin/env bash
# sync-upstream.sh - Synchronize FreeOS with upstream CachyOS and Liberated systemd
# Called by GitHub Actions or can be run manually.
set -euo pipefail

CACHYOS_REMOTE="https://github.com/CachyOS/linux-cachyos.git"
CACHYOS_BRANCH="master"
GIT_FETCH_DEPTH=0
SYSTEMD_REMOTE="https://github.com/Jeffrey-Sardina/systemd.git"
SYSTEMD_BRANCH="main"

DRY_RUN="${DRY_RUN:-false}"
CHANGES=0

log() { echo "[sync-upstream] $*"; }

# --- CachyOS sync ---
sync_cachyos() {
    log "Checking CachyOS/linux-cachyos for updates..."

    # Fetch latest from CachyOS
    if ! git remote get-url upstream-cachyos >/dev/null 2>&1; then
        log "Adding CachyOS remote..."
        git remote add upstream-cachyos "$CACHYOS_REMOTE"
    fi
    log "Fetching upstream-cachyos/$CACHYOS_BRANCH ..."
    git fetch upstream-cachyos "$CACHYOS_BRANCH" --tags

    LOCAL_HEAD=$(git rev-parse HEAD)
    UPSTREAM_HEAD=$(git rev-parse "upstream-cachyos/$CACHYOS_BRANCH")

    log "CachyOS: local=$LOCAL_HEAD, upstream=$UPSTREAM_HEAD"

    if [ "$LOCAL_HEAD" = "$UPSTREAM_HEAD" ]; then
        log "CachyOS: Already at upstream HEAD. No new updates."
        return 0
    fi

    MERGE_BASE=$(git merge-base HEAD "upstream-cachyos/$CACHYOS_BRANCH" 2>/dev/null || true)
    if [ -z "$MERGE_BASE" ]; then
        log "CachyOS: No common merge base found. Treating as diverged histories."
        MERGE_BASE=""
    else
        log "CachyOS: merge-base=$MERGE_BASE"
    fi

    if [ -n "$MERGE_BASE" ] && [ "$MERGE_BASE" = "$UPSTREAM_HEAD" ]; then
        log "CachyOS: No new upstream commits since last merge."
        return 0
    fi

    if [ -n "$MERGE_BASE" ] && [ "$MERGE_BASE" = "$LOCAL_HEAD" ]; then
        log "CachyOS: Fast-forward possible."
    else
        log "CachyOS: Diverged, need merge."
    fi

    log "CachyOS has updates. Syncing..."
    CHANGES=1

    if [ "$DRY_RUN" = "true" ]; then
        log "DRY RUN: would merge CachyOS updates"
        return 0
    fi

    # Merge upstream changes, preferring ours for README and branding
    if git merge "upstream-cachyos/$CACHYOS_BRANCH" \
        --no-edit \
        -m "sync: merge CachyOS/linux-cachyos upstream updates" \
        --allow-unrelated-histories 2>/dev/null; then
        # Reset .github folder to keep our workflows/CI config untouched
        git checkout --ours -- .github/ || true
        git add .github/ || true
        replace_systemd_refs || true
        return 0
    fi

    log "Merge conflict detected, resolving with ours strategy for FreeOS files..."

    # Check if there are any unresolved conflicts left
    UNRESOLVED=$(git diff --name-only --diff-filter=U || true)
    if [ -z "$UNRESOLVED" ]; then
        log "All conflicts already resolved. Committing..."
        git checkout --ours -- .github/ || true
        git add .github/ || true
        git commit --no-edit || true
        replace_systemd_refs || true
        return 0
    fi
    log "Unresolved files: $UNRESOLVED"

    # Resolve conflicts: prefer upstream for kernel files, ours for branding
    # Accept all upstream changes for kernel directories
    for conflict in $(git diff --name-only --diff-filter=U || true); do
        case "$conflict" in
            README.md|CODE_OF_CONDUCT.md|CONTRIBUTING.md|.github/FUNDING.yml)
                git checkout --ours -- "$conflict" || true
                git add "$conflict" || true
                ;;
            .github/*)
                # Skip .github files entirely — keep ours to avoid workflow permission issues
                git checkout --ours -- "$conflict" || true
                git add "$conflict" || true
                ;;
            *)
                git checkout --theirs -- "$conflict" || true
                git add "$conflict" || true
                ;;
        esac
    done
    # Reset entire .github folder to keep our workflows/CI config untouched
    git checkout --ours -- .github/ || true
    git add .github/ || true
    git commit --no-edit || true

    # Replace any systemd/systemd references that may have been introduced
    replace_systemd_refs || true
}

# --- Liberated systemd sync ---
sync_systemd() {
    log "Checking Jeffrey-Sardina/systemd for updates..."

    git submodule update --init --remote systemd 2>/dev/null || {
        log "Initializing systemd submodule..."
        git submodule update --init systemd
        git -C systemd remote add origin "$SYSTEMD_REMOTE" 2>/dev/null || true
    }

    cd systemd
    # Ensure we can fetch from the actual upstream remote
    if ! git remote get-url origin >/dev/null 2>&1; then
        git remote add origin "$SYSTEMD_REMOTE"
    fi
    git fetch origin "$SYSTEMD_BRANCH"
    SYSTEMD_LATEST=$(git rev-parse "origin/$SYSTEMD_BRANCH")
    cd ..

    SYSTEMD_CURRENT=$(git ls-tree HEAD -- systemd | awk '{print $3}')

    if [ "$SYSTEMD_CURRENT" = "$SYSTEMD_LATEST" ]; then
        log "Liberated systemd: No new updates (current=$SYSTEMD_CURRENT, latest=$SYSTEMD_LATEST)."
        return 0
    fi

    log "Liberated systemd has updates. Updating submodule..."
    log "  Current: $SYSTEMD_CURRENT"
    log "  Latest:  $SYSTEMD_LATEST"
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
    while IFS= read -r -d '' pkgbuild; do
        if grep -q 'https://github.com/systemd/systemd/' "$pkgbuild" 2>/dev/null; then
            sed -i 's|https://github.com/systemd/systemd/|https://github.com/Jeffrey-Sardina/systemd/|g' "$pkgbuild" || true
            git add "$pkgbuild" || true
            CHANGED=1
        fi
    done < <(find . -name PKGBUILD -not -path "./systemd/*" -print0 2>/dev/null)

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

    # Allow skipping CachyOS sync when only systemd is needed
    if [ "${SYNC_CACHYOS:-1}" = "1" ]; then
        sync_cachyos
    else
        log "SYNC_CACHYOS=0: Skipping CachyOS sync."
    fi
    # Allow skipping systemd sync when only cachyOS is needed
    if [ "${SYNC_SYSTEMD:-1}" = "1" ]; then
        sync_systemd
    else
        log "SYNC_SYSTEMD=0: Skipping systemd sync."
    fi

    if [ "$CHANGES" = "1" ]; then
        log "Updates applied and committed."
    else
        log "No updates found."
    fi

    # Output for GitHub Actions
    echo "has_changes=$CHANGES" >> "$GITHUB_OUTPUT" 2>/dev/null || true
}

main
