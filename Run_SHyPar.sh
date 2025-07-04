#!/bin/bash

#==============================================================================
#   SHyPar Automation Workflow 
#
#   This script incorporates final user feedback for cleaner file handling:
#   1. Intermediate files (.ER, .idx) are stored in a temporary directory.
#   2. The final partition file is correctly located in the data directory.
#
#   Usage:
#   ./Run_SHyPar.sh <hypergraph_file_name> <L> <k> <epsilon>
#
#==============================================================================

# --- Configuration ---
readonly BASE_DIR="/home/CAMPUS/hsajadin"
readonly SHYPAR_DIR="$BASE_DIR/SHyPar"
readonly DATA_DIR="$SHYPAR_DIR/data"
readonly HYPEREF_DIR="$SHYPAR_DIR/HyperEF"
readonly HYPERSF_DIR="$SHYPAR_DIR/HyperSF"
readonly KAHYPAR_DIRS=(
    "$BASE_DIR/SHyPar/KaHyPar/KaHyPar_1/kahypar/build/kahypar/application"   # 1
    "$BASE_DIR/SHyPar/KaHyPar/KaHyPar_2/kahypar/build/kahypar/application"   # 2
    "$BASE_DIR/SHyPar/KaHyPar/KaHyPar_3/kahypar/build/kahypar/application"   # 3
    "$BASE_DIR/SHyPar/KaHyPar/KaHyPar_4/kahypar/build/kahypar/application"   # 4
    "$BASE_DIR/SHyPar/KaHyPar/KaHyPar_5/kahypar/build/kahypar/application"   # 5
    "$BASE_DIR/SHyPar/KaHyPar/KaHyPar_6/kahypar/build/kahypar/application"   # 6
    "$BASE_DIR/SHyPar/KaHyPar/KaHyPar_7/kahypar/build/kahypar/application"   # 7
    "$BASE_DIR/SHyPar/KaHyPar/KaHyPar_8/kahypar/build/kahypar/application"   # 8
    "$BASE_DIR/SHyPar/KaHyPar/KaHyPar_9/kahypar/build/kahypar/application"   # 9
)

# --- Input Validation ---
if [ "$#" -ne 4 ]; then
    echo "Error: Invalid number of arguments."
    echo "Usage: $0 <hypergraph_file_name> <L> <k> <epsilon>"
    exit 1
fi

readonly HGR_FILENAME=$1
readonly L_PARAM=$2
readonly K_PARTITIONS=$3
readonly EPSILON_IMBALANCE=$4
readonly HGR_FILE_PATH="$DATA_DIR/$HGR_FILENAME"

if [ ! -f "$HGR_FILE_PATH" ]; then
    echo "Error: Hypergraph file not found at '$HGR_FILE_PATH'"
    exit 1
fi

# --- Main Logic ---
readonly TMP_DIR=$(mktemp -d -p "$SHYPAR_DIR" "shypar_run_XXXXXX")
echo "Created temporary working directory: $TMP_DIR"
cd "$SHYPAR_DIR" || exit
echo "---"
echo "Step 1: Running Julia Pre-processing..."
(cd "$HYPEREF_DIR" && julia Run_HyperEF.jl "$HGR_FILE_PATH" "$L_PARAM")
(cd "$HYPERSF_DIR" && julia Run_HyperSF.jl "$HGR_FILE_PATH" "$L_PARAM")


echo "  -> Moving intermediate files to '$TMP_DIR'..."
mv -f "$DATA_DIR/${HGR_FILENAME}.ER" "$TMP_DIR/"
mv -f "$DATA_DIR/${HGR_FILENAME}".L*.{EF,SF}.idx "$TMP_DIR/" 2>/dev/null


readonly ER_FILE_PATH="$TMP_DIR/${HGR_FILENAME}.ER"

if [ ! -f "$ER_FILE_PATH" ]; then
    echo "Error: Expected ER file was not generated or moved to temp directory correctly."
    rm -rf "$TMP_DIR"
    exit 1
fi
echo "Julia pre-processing complete."
echo "---"
echo "Step 2: Running all KaHyPar configurations in parallel..."

min_cut=999999999
best_kahypar_dir=""
best_idx_file_path=""
best_kahypar_args=""

for type in EF SF; do
    for i in $(seq 1 "$L_PARAM"); do
        idx_file_path="$TMP_DIR/${HGR_FILENAME}.L${i}.${type}.idx"

        if [ ! -f "$idx_file_path" ]; then
            echo "Warning: Index file '$idx_file_path' not found. Skipping."
            continue
        fi
        # echo "  -> Processing index file: $(basename "$idx_file_path")"
        pids=()
        for j in "${!KAHYPAR_DIRS[@]}"; do
            kahypar_app_dir="${KAHYPAR_DIRS[$j]}"
            log_file="$TMP_DIR/kahypar_run_j${j}_i${i}_${type}.log"
            base_args="-h $HGR_FILE_PATH -k $K_PARTITIONS -e $EPSILON_IMBALANCE -o km1 -m direct -p ../../../config/km1_kKaHyPar_sea20.ini"
            if [[ "$j" -eq 2 || "$j" -eq 5 || "$j" -eq 8 ]]; then
                current_args="$ER_FILE_PATH $idx_file_path $base_args --c-rating-use-communities 0"
            else
                current_args="$ER_FILE_PATH $idx_file_path $base_args"
            fi
            (cd "$kahypar_app_dir" && ./KaHyPar $current_args > "$log_file" 2>&1) &
            pids+=($!)
        done
        for pid in "${pids[@]}"; do
            wait "$pid"
        done
        for j in "${!KAHYPAR_DIRS[@]}"; do
            log_file="$TMP_DIR/kahypar_run_j${j}_i${i}_${type}.log"
            result_line=$(grep "Hyperedge Cut" "$log_file")
            if [ -n "$result_line" ]; then
                current_cut=$(echo "$result_line" | awk '{print $5}')
                if [[ "$current_cut" =~ ^[0-9]+$ ]] && [ "$current_cut" -lt "$min_cut" ]; then
                    min_cut=$current_cut
                    best_kahypar_dir="${KAHYPAR_DIRS[$j]}"
                    best_idx_file_path=$idx_file_path
                    if [[ "$j" -eq 2 || "$j" -eq 5 || "$j" -eq 8 ]]; then
                         best_kahypar_args="$ER_FILE_PATH $idx_file_path $base_args --c-rating-use-communities 0"
                    else
                         best_kahypar_args="$ER_FILE_PATH $idx_file_path $base_args"
                    fi
                    echo "      New best cut found: $min_cut ($(basename "$idx_file_path"))"
                fi
            fi
        done
    done
done
echo "KaHyPar evaluation complete."

# ---
# 3. Rerun Best Configuration and Save Output
echo "---"
echo "Step 3: Re-running best configuration to generate final partition file..."
if [ -z "$best_kahypar_dir" ]; then
    echo "Error: No successful KaHyPar run found. Could not determine best result."
    rm -rf "$TMP_DIR"
    exit 1
fi
echo "  -> Best Result Details:"
echo "     - Minimum Cut: $min_cut"
echo "     - KaHyPar Dir: $best_kahypar_dir"
echo "     - Index File:  $(basename "$best_idx__path")"
final_command_args="$best_kahypar_args -w1"
final_output_filename="${HGR_FILENAME}.part${K_PARTITIONS}.l${L_PARAM}.e${EPSILON_IMBALANCE}.partition"
echo "  -> Executing final command..."
(cd "$best_kahypar_dir" && ./KaHyPar $final_command_args)

# Construct the exact filename based on the known output format
expected_filename="${HGR_FILENAME}.part${K_PARTITIONS}.epsilon${EPSILON_IMBALANCE}.seed-1.KaHyPar"


partition_file="$DATA_DIR/$expected_filename"

if [ -f "$partition_file" ]; then
    # Move the file from the data directory and rename it in the main project directory
    mv "$partition_file" "$SHYPAR_DIR/$final_output_filename"
    echo "Final partition file moved from '$DATA_DIR' and saved as: '$SHYPAR_DIR/$final_output_filename'"
else
    echo "Warning: Could not find the final partition output file '$expected_filename' in '$DATA_DIR'."
fi

# ---
# 4. Cleanup
echo "---"
echo "Step 4: Cleaning up temporary files..."
rm -rf "$TMP_DIR"
echo "  -> Removed temporary directory (including all logs and intermediate files)."
echo "---"
echo "Workflow Finished Successfully!"