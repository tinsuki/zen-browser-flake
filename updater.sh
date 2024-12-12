quiet=0
dry_run=0
verbose=0

help () {
  echo "Usage: updater.sh [options]"
  echo "Options:"
  echo "  -q, --quiet    Run in quiet mode"
  echo "  -d, --dry-run  Run in dry-run mode"
  echo "  -v, --verbose  Run in verbose mode"
  echo "  -h, --help     Display this help message"
}

for arg in "$@"; do
  case $arg in
    -q|--quiet)
      quiet=1
      shift
      ;;
    -d|--dry-run)
      dry_run=1
      shift
      ;;
    -v|--verbose)
      verbose=1
      shift
      ;;
    -h|--help)
      help
      exit 0
      ;;
    *)
      echo "Invalid option: $arg"
      help
      exit 1
  esac
done

# verify that nix-prefetch-url can be used to download the source
if command -v nix-prefetch-url > /dev/null; then
  if [ $quiet -eq 0 ]; then
    echo "nix-prefetch-url is installed"
  fi
else
  if [ $quiet -eq 0 ]; then
    echo "nix-prefetch-url is not installed, installing nix"
  fi
  if [ $verbose -eq 1 ]; then
    sh <(curl -L https://nixos.org/nix/install) --daemon --yes
  else
    sh <(curl -L https://nixos.org/nix/install) --daemon --yes > /dev/null
  fi
fi

if [ $quiet -eq 0 ]; then
  echo "#####"
  echo "Step 1: Checking Zen Browser version from Git"
  echo "#####"
fi


if ! test -d desktop; then
  git clone https://github.com/zen-browser/desktop.git
fi

cd desktop || { echo "Error: desktop directory not found"; exit 1; }

git fetch --all
git checkout dev
git pull

zen_version=$(git describe --tags --abbrev=0)

if [ $quiet -eq 0 ]; then
  echo "Zen version from Git: $zen_version"

  echo "#####"
  echo "Step 2: Checking Zen Browser version locally"
  echo "#####"
fi

cd .. || exit 1

if ! test -f flake.nix; then
  echo "Error: flake.nix not found"
  exit 1
fi

local_version=$(grep -Po 'version = \"\K[^"]+' flake.nix)

if [ $quiet -eq 0 ]; then
  echo "Local version: $local_version"

  echo "#####"
  echo "Step 3: Comparing versions"
  echo "#####"
fi

if [ "$zen_version" == "$local_version" ]; then
  if [ $quiet -eq 0 ]; then
    echo "Versions match, no update required."
    if [ $verbose -eq 1 ]; then
      echo "Zen version: $zen_version"
      echo "Local version: $local_version"
    fi
  fi
  exit 0
fi


if [ $quiet -eq 0 ]; then
  echo "Versions differ. Updating flake.nix..."
fi

# Fetch the latest source hash
specsha=$(nix-prefetch-url --unpack https://github.com/zen-browser/desktop/releases/download/$zen_version/zen.linux-generic.tar.bz2)
gensha=$(nix-prefetch-url --unpack https://github.com/zen-browser/desktop/releases/download/$zen_version/zen.linux-generic.tar.bz2)

if [ $verbose -eq 1 ]; then
  echo "Specific hash: $specsha"
  echo "Generic hash: $specsha"
fi

# Update flake.nix using a template
# replace the $version, $specsha, and $gensha placeholders
mv flake.nix flake.nix.bak
cp template flake.nix
sed -i 's/$version/'"$zen_version"'/g' flake.nix
sed -i 's/$specsha/'"$specsha"'/g' flake.nix
sed -i 's/$gensha/'"$gensha"'/g' flake.nix

if [ $verbose -eq 1 ]; then
  diff flake.nix.bak flake.nix
fi

if [ $quiet -eq 0 ]; then
  echo "flake.nix updated."

  echo "#####"
  echo "Step 4: Pushing update to GitHub"
  echo "#####"
fi

if [ $dry_run -eq 1 ]; then
  if [ $quiet -eq 0 ]; then
    echo "Dry run mode enabled. No changes will be pushed to GitHub."
  fi
  exit 0
fi

if ! git status | grep -q "nothing to commit"; then
  git add flake.nix
  git commit -m "Update flake.nix for Zen Browser from $local_version to $zen_version"
  git push origin dev
  if [ $quiet -eq 0 ]; then
    echo "Update pushed to GitHub."
  fi
else
  if [ $quiet -eq 0 ]; then
    echo "No changes to commit."
  fi
fi

if [ $quiet -eq 0 ]; then
  echo "#####"
  echo "Done!"
  echo "#####"
fi