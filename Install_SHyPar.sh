#!/bin/bash

#==============================================================================
#   KaHyPar Bulk Installation Script (Parallel Version)
#
#   This script automates the build process for multiple modified KaHyPar
#   instances, running them in parallel to save time. It iterates through
#   a predefined list of directories, creates a 'build' subdirectory in
#   each, and runs cmake/make.
#
#   Directory Structure Assumption:
#   This script should be placed in the main SHyPar project directory.
#   The individual KaHyPar source folders should be inside a subdirectory
#   (e.g., "KaHyPar"), like so:
#
#==============================================================================

# --- Configuration ---

# Get the directory where the script is located to use as the base project directory.
readonly BASE_DIR=$(pwd)

# Define the subdirectory that contains all the KaHyPar source folders.
readonly SOURCES_SUBDIR="KaHyPar"

# Define the names of all KaHyPar source directories
readonly KAHYPAR_DIRS=(
    "KaHyPar_1" "KaHyPar_2" "KaHyPar_3" "KaHyPar_4" "KaHyPar_5"
    "KaHyPar_6" "KaHyPar_7" "KaHyPar_8" "KaHyPar_9"
)

# Colors for terminal output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

# --- Prerequisite Check ---

echo "Checking for necessary tools (cmake, git)..."
for tool in cmake git; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}Error: Required tool '$tool' is not installed. Please install it and try again.${NC}"
        exit 1
    fi
done
echo -e "${GREEN}All necessary tools are present.${NC}"
echo

# --- Build Function ---

# This function contains the logic to build a single KaHyPar instance.
# It's designed to be run in the background as a parallel job.
build_one_kahypar() {
    local dir_name=$1
    local full_path="$BASE_DIR/$SOURCES_SUBDIR/$dir_name/kahypar"
    local build_dir="$full_path/build"

    echo "[${dir_name}] Starting build process..."

    # Check if the source directory actually exists
    if [ ! -d "$full_path" ]; then
        echo -e "[${dir_name}] ${RED}Warning: Directory '$full_path' not found. Skipping.${NC}"
        return
    fi

    # Create the build directory
    mkdir -p "$build_dir"

    # Run the build process.
    # The 'make -j' command without a number uses all available CPU cores.
    # Output is redirected to a log file to prevent interleaved terminal spam.
    local log_file="$BASE_DIR/build_${dir_name}.log"
    if (cd "$build_dir" && cmake .. -DCMAKE_BUILD_TYPE=RELEASE && make -j); then
        echo -e "[${dir_name}] ${GREEN}Successfully built.${NC} See log for details: ${log_file}"
    else
        echo -e "[${dir_name}] ${RED}Error building. Please check the log file: ${log_file}${NC}"
    fi
}

# Export the function so it is available to the subshells created by parallel execution.
export -f build_one_kahypar
export BASE_DIR SOURCES_SUBDIR GREEN RED NC # Export readonly variables needed by the function

# --- Main Build Logic ---

echo "Launching parallel builds for all KaHyPar instances..."
echo "Build logs will be saved to files named 'build_*.log' in this directory."
echo

# Launch all build jobs in the background
for dir_name in "${KAHYPAR_DIRS[@]}"; do
    # Each call to the function is a separate job running in parallel.
    # All output is handled inside the function.
    build_one_kahypar "$dir_name" > "$BASE_DIR/build_${dir_name}.log" 2>&1 &
done

# Wait for all background jobs to complete
wait

echo
echo "====================================================================="
echo -e "${GREEN}All parallel builds finished! Check logs for success or failure.${NC}"
echo "====================================================================="
