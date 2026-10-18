function nixos-update --description 'Update nixpkgs, test the NixOS generation, then switch'
    if test (count $argv) -ne 0
        echo 'Usage: nixos-update' >&2
        return 2
    end

    set -l flake_dir /etc/nixos
    set -q NIXOS_FLAKE_DIR; and set flake_dir "$NIXOS_FLAKE_DIR"

    set -l configuration nixos
    set -q NIXOS_CONFIGURATION; and set configuration "$NIXOS_CONFIGURATION"

    if not test -f "$flake_dir/flake.nix"
        echo "nixos-update: no flake.nix found in $flake_dir" >&2
        return 2
    end

    set -l flake_ref "$flake_dir#$configuration"

    echo '[1/3] Updating flake inputs...'
    command nix flake update --flake "$flake_dir"
    set -l update_status $status
    if test $update_status -ne 0
        echo 'nixos-update: update failed; test and switch were skipped.' >&2
        return $update_status
    end

    echo '[2/3] Testing the new NixOS generation...'
    command sudo nixos-rebuild test --flake "$flake_ref"
    set -l test_status $status
    if test $test_status -ne 0
        echo 'nixos-update: test failed; switch was skipped.' >&2
        return $test_status
    end

    echo '[3/3] Switching to the tested generation...'
    command sudo nixos-rebuild switch --flake "$flake_ref"
    set -l switch_status $status
    if test $switch_status -ne 0
        echo 'nixos-update: switch failed.' >&2
        return $switch_status
    end

    echo 'NixOS update complete.'
end
