#!/bin/bash

# Shell Script Utility - Parse shell scripts for comments and commands, provide UI to run them
# Similar to psutil.ps1 but for shell scripts

# Configuration
SCRIPT_EXTENSIONS=("*.sh" "*.bash")
SCRIPT_BLACKLIST=("shellutil.sh" "test.sh" "db.sh" "gnomeutil.sh")
DATA_DIR="$HOME/.shellutil"
FAVORITES_DIR="$DATA_DIR/favorites"
LOGS_DIR="$DATA_DIR/logs"
SCRIPTS_DIR="$DATA_DIR/scripts"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
declare -a TASKS=()
declare -a TASK_DESCRIPTIONS=()
declare -a TASK_COMMANDS=()
declare -a TASK_FILES=()
declare -a TASK_LINE_NUMBERS=()
declare -a SELECTED_TASKS=()
# declare -a ALL_SCRIPTS=()

# Initialize directories
init_directories() {
    local dirs=("$DATA_DIR" "$FAVORITES_DIR" "$LOGS_DIR" "$SCRIPTS_DIR")
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
        fi
    done
}

# Check if zenity is available for GUI
check_gui_availability() {
    if command -v zenity &> /dev/null; then
        return 0
    fi
    return 1
}

# Parse a script file for comments and commands
parse_script_file() {
    local file_path="$1"
    local file_name
    file_name=$(basename "$file_path")
    
    if [[ ! -f "$file_path" ]]; then
        echo -e "${RED}Error: File not found: $file_path${NC}"
        return 1
    fi
    
    local current_description=""
    local current_command=""
    local line_number=0
    local in_command=false
    local tasks_found=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_number++))
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')  # trim whitespace
        
        if [[ "$line" =~ ^#(.*)$ ]]; then
            # If we have a previous task, save it
            if [[ -n "$current_description" && -n "$current_command" ]]; then
                TASKS+=("${#TASK_DESCRIPTIONS[@]}")
                TASK_DESCRIPTIONS+=("$current_description")
                TASK_COMMANDS+=("$current_command")
                TASK_FILES+=("$file_name")
                TASK_LINE_NUMBERS+=("$line_number")
                ((tasks_found++))
            fi
            
            # Start new task
            current_description="${BASH_REMATCH[1]}"
            current_description=$(echo "$current_description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            current_command=""
            in_command=true
            
        elif [[ -n "$line" && ! "$line" =~ ^# && "$in_command" == true ]]; then
            # Add to current command
            if [[ -n "$current_command" ]]; then
                current_command="$current_command"$'\n'"$line"
            else
                current_command="$line"
            fi
        elif [[ -z "$line" && "$in_command" == true ]]; then
            # Empty line might end the command block
            in_command=false
        fi
    done < "$file_path"
    
    # Add the last task if it exists
    if [[ -n "$current_description" && -n "$current_command" ]]; then
        TASKS+=("${#TASK_DESCRIPTIONS[@]}")
        TASK_DESCRIPTIONS+=("$current_description")
        TASK_COMMANDS+=("$current_command")
        TASK_FILES+=("$file_name")
        TASK_LINE_NUMBERS+=("$line_number")
        ((tasks_found++))
    fi
    
    # If no tasks found, treat entire file as single task
    if [[ $tasks_found -eq 0 ]]; then
        TASKS+=(${#TASK_DESCRIPTIONS[@]})
        TASK_DESCRIPTIONS+=("Execute entire file: $file_name")
        TASK_COMMANDS+=("$(cat "$file_path")")
        TASK_FILES+=("$file_name")
        TASK_LINE_NUMBERS+=(1)
        ((tasks_found++))
    fi
    
    return 0
}

# Parse all bash executable files in root directory
parse_all_scripts() {
    # Clear previous tasks
    TASKS=()
    TASK_DESCRIPTIONS=()
    TASK_COMMANDS=()
    TASK_FILES=()
    TASK_LINE_NUMBERS=()
    
    local script_files=()
    
    # Find all bash script files
    for pattern in "${SCRIPT_EXTENSIONS[@]}"; do
        while IFS= read -r -d '' file; do
            local basename_val
            basename_val=$(basename "$file")
            local is_blacklisted=false
            
            for blacklisted in "${SCRIPT_BLACKLIST[@]}"; do
                if [[ "$basename_val" == "$blacklisted" ]]; then
                    is_blacklisted=true
                    break
                fi
            done
            
            if [[ "$is_blacklisted" == false ]]; then
                script_files+=("$file")
            fi
        done < <(find . -maxdepth 1 -name "$pattern" -type f -print0)
    done
    
    # Also find executable files without extension that start with #!/bin/bash
    while IFS= read -r -d '' file; do
        if [[ -x "$file" ]]; then
            local first_line
            first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
            if [[ "$first_line" =~ ^#!/bin/bash || "$first_line" =~ ^#!/usr/bin/env[[:space:]]+bash ]]; then
                local basename_val
                basename_val=$(basename "$file")
                local is_blacklisted=false
                
                for blacklisted in "${SCRIPT_BLACKLIST[@]}"; do
                    if [[ "$basename_val" == "$blacklisted" ]]; then
                        is_blacklisted=true
                        break
                    fi
                done
                
                if [[ "$is_blacklisted" == false ]]; then
                    script_files+=("$file")
                fi
            fi
        fi
    done < <(find . -maxdepth 1 -type f -executable -print0)
    
    if [[ ${#script_files[@]} -eq 0 ]]; then
        >&2 echo -e "${RED}No bash script files found in current directory${NC}"
        return 1
    fi
    
    # Parse all found scripts
    local total_tasks_found=0
    for script_file in "${script_files[@]}"; do
        local before_count=${#TASKS[@]}
        parse_script_file "$script_file"
        local after_count=${#TASKS[@]}
        local file_tasks=$((after_count - before_count))
        total_tasks_found=$((total_tasks_found + file_tasks))
    done
    
    return 0
}



# Display tasks using zenity GUI
display_tasks_gui() {
    local checklist_items=()
    local all_selected=true
    local any_selected=false

    # Check current selection state
    for i in "${!TASKS[@]}"; do
        local is_selected=false
        for selected_task in "${SELECTED_TASKS[@]}"; do
            if [[ "$selected_task" == "$i" ]]; then
                is_selected=true
                any_selected=true
                break
            fi
        done
        if [[ "$is_selected" == false ]]; then
            all_selected=false
        fi
    done

    # Build checklist items
    for i in "${!TASKS[@]}"; do
        local selected="FALSE"
        local is_selected=false
        for selected_task in "${SELECTED_TASKS[@]}"; do
            if [[ "$selected_task" == "$i" ]]; then
                is_selected=true
                break
            fi
        done

        if [[ "$is_selected" == true ]]; then
            selected="TRUE"
        fi

        local task_desc="${TASK_DESCRIPTIONS[$i]}"

        # Simplify escaping of special characters for zenity compatibility
        task_desc=$(echo "$task_desc" | sed 's/"/\\"/g; s/\$/\\$/g')

        checklist_items+=("$selected")
        checklist_items+=("$task_desc")
        checklist_items+=("${TASK_FILES[$i]}")
    done

    if [[ ${#checklist_items[@]} -eq 0 ]]; then
        zenity --error --title="No Tasks Found" --text="No tasks found in the bash scripts.\n\nPlease ensure your scripts contain properly formatted task comments." --width=350
        return 1
    fi

    # Create simple header text
    local header_text="Select tasks to execute and click Run Selected"

    # Determine toggle button label based on current state
    local toggle_button
    if [[ $all_selected == true && $any_selected == true ]]; then
        toggle_button="Unselect All"
    else
        toggle_button="Select All"
    fi

    # Use static run button text
    local run_button="Run Selected"

    local selection
    selection=$(zenity --list --checklist \
        --title="Shell Script Utility - All Scripts" \
        --text="$header_text" \
        --column="Select" \
        --column="Task" \
        --column="Source File" \
        --width=900 \
        --height=650 \
        --separator="|" \
        --ok-label="$run_button" \
        --cancel-label="Exit" \
        --extra-button="$toggle_button" \
        "${checklist_items[@]}")

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        if [[ -n "$selection" ]]; then
            # Parse selected task descriptions and find their indices
            SELECTED_TASKS=()
            IFS='|' read -ra SELECTED_DESCS <<< "$selection"
            for desc in "${SELECTED_DESCS[@]}"; do
                # Find the index of this description in TASK_DESCRIPTIONS
                for i in "${!TASK_DESCRIPTIONS[@]}"; do
                    local task_desc="${TASK_DESCRIPTIONS[$i]}"
                    
                    # Escape special characters for comparison
                    local escaped_desc
                    escaped_desc=$(echo "$task_desc" | sed 's/"/\\"/g; s/\$/\\$/g')
                    if [[ "$desc" == "$escaped_desc" ]]; then
                        SELECTED_TASKS+=("$i")
                        break
                    fi
                done
            done
            return 0
        else
            zenity --warning --title="No Selection" --text="Please select at least one task to execute.\n\nUse the checkboxes to select tasks or click '$toggle_button'." --width=350
            return 1
        fi
    elif [[ $exit_code -eq 1 ]]; then
        # Check if this is an extra button click or cancel button click
        if [[ -n "$selection" ]]; then
            case "$selection" in
                "Select All")
                    # Select all tasks and redisplay dialog
                    SELECTED_TASKS=()
                    for i in "${!TASKS[@]}"; do
                        SELECTED_TASKS+=("$i")
                    done
                    return 2  # Special return code to redisplay dialog
                    ;;
                "Unselect All")
                    # Clear all selections and redisplay dialog
                    SELECTED_TASKS=()
                    return 2  # Special return code to redisplay dialog
                    ;;
            esac
        fi
        # If we get here, user clicked cancel button or closed window - exit application
        return 1
    fi
    
    # User closed the window - exit application
    return 1
}


# Execute tasks with GUI feedback
execute_tasks_gui() {
    if [[ ${#SELECTED_TASKS[@]} -eq 0 ]]; then
        zenity --error --text="No tasks selected for execution."
        return 1
    fi

    local log_file
    log_file="$LOGS_DIR/execution_$(date +%Y%m%d_%H%M%S).log"
    local log_timestamp
    log_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$log_timestamp START Execution session started" > "$log_file"
    echo "$log_timestamp INFO Selected tasks: ${#SELECTED_TASKS[@]}" >> "$log_file"
    echo "" >> "$log_file"

    # Launch log viewer dialog first (before progress dialog)
    # Use a simple approach that works with all zenity versions
    (
        # Start with current log content
        cat "$log_file"
        # Then follow the file for new content
        tail -f "$log_file" -n +0
    ) | zenity --text-info \
        --title="Execution Logs - Live View" \
        --width=600 \
        --height=400 \
        --auto-scroll &
    
    local log_viewer_pid=$!
    
    # Give log viewer time to start
    sleep 1

    local total_tasks=${#SELECTED_TASKS[@]}
    local completed=0
    local success_count=0
    local failed_count=0

    # Create temporary files to track progress
    local success_file
    local failed_file
    success_file=$(mktemp)
    failed_file=$(mktemp)
    echo "0" > "$success_file"
    echo "0" > "$failed_file"

    # Execute tasks with progress dialog
    (
        for task_index in "${SELECTED_TASKS[@]}"; do
            local progress=$((completed * 100 / total_tasks))
            echo "$progress"
            echo "# Executing task $((completed + 1))/$total_tasks: ${TASK_DESCRIPTIONS[$task_index]}"
            
            # POSIX log format: timestamp verb message
            local timestamp
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            echo "$timestamp START Task: ${TASK_DESCRIPTIONS[$task_index]}" >> "$log_file"
            echo "$timestamp INFO File: ${TASK_FILES[$task_index]}" >> "$log_file"
            
            # Execute the command and capture output
            local temp_log
            temp_log=$(mktemp)
            if eval "${TASK_COMMANDS[$task_index]}" >> "$temp_log" 2>&1; then
                echo "$timestamp SUCCESS Task completed successfully" >> "$log_file"
                # Update success count
                local current_success
                current_success=$(cat "$success_file")
                echo $((current_success + 1)) > "$success_file"
            else
                echo "$timestamp ERROR Task failed with exit code $?" >> "$log_file"
                # Update failed count
                local current_failed
                current_failed=$(cat "$failed_file")
                echo $((current_failed + 1)) > "$failed_file"
            fi
            
            # Append command output to main log
            if [[ -s "$temp_log" ]]; then
                echo "$timestamp OUTPUT Command output:" >> "$log_file"
                while IFS= read -r line; do
                    echo "$timestamp OUTPUT $line" >> "$log_file"
                done < "$temp_log"
            fi
            rm -f "$temp_log"
            
            echo "$timestamp END Task execution completed" >> "$log_file"
            echo "" >> "$log_file"

            completed=$((completed + 1))
            
            # Add a small delay to make progress visible
            sleep 0.5
        done
        
        # Read final counts from temporary files and show results in progress dialog
        local final_success_count
        local final_failed_count
        final_success_count=$(cat "$success_file")
        final_failed_count=$(cat "$failed_file")
        
        echo "100"
        
        # Create summary message for progress dialog - all in header line
        if [[ $final_failed_count -eq 0 ]]; then
            echo "# All tasks completed successfully! (Success: $final_success_count, Failed: 0)"
        else
            echo "# Execution completed with issues (Success: $final_success_count, Failed: $final_failed_count)"
        fi
        
        # Brief pause to show results
        sleep 2
        
    ) | zenity --progress \
        --title="Shell Script Utility - Task Execution" \
        --text="Preparing to execute tasks..." \
        --auto-close \
        --percentage=0 \
        --width=600 \
        --height=150 &

    local progress_pid=$!

    # Wait for the progress dialog to complete
    wait $progress_pid
    
    # # Clean up log viewer dialog if still running
    # if kill -0 $log_viewer_pid 2>/dev/null; then
    #     kill $log_viewer_pid 2>/dev/null
    # fi

    # Read final counts from temporary files for logging
    success_count=$(cat "$success_file")
    failed_count=$(cat "$failed_file")
    rm -f "$success_file" "$failed_file"

    # Add final log entry
    local final_timestamp
    final_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$final_timestamp END Execution session completed" >> "$log_file"
    echo "$final_timestamp SUMMARY Success: $success_count, Failed: $failed_count" >> "$log_file"
    
    # Return special code to show task list again
    return 2
}



# Find script files in current directory
find_script_files() {
    local script_files=()
    
    for pattern in "${SCRIPT_EXTENSIONS[@]}"; do
        while IFS= read -r -d '' file; do
            local basename_val
            basename_val=$(basename "$file")
            local is_blacklisted=false
            
            for blacklisted in "${SCRIPT_BLACKLIST[@]}"; do
                if [[ "$basename_val" == "$blacklisted" ]]; then
                    is_blacklisted=true
                    break
                fi
            done
            
            if [[ "$is_blacklisted" == false ]]; then
                script_files+=("$file")
            fi
        done < <(find . -maxdepth 1 -name "$pattern" -type f -print0)
    done
    
    printf '%s\n' "${script_files[@]}"
}



# Help function
show_help() {
    echo "Shell Script Utility - Parse and execute shell script tasks"
    echo ""
    echo "Usage: $0 [OPTIONS] [SCRIPT_FILE]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -f, --file     Specify script file directly"
    echo ""
    echo "Behavior:"
    echo "  Without -f:    Parse all bash executable files in root directory"
    echo "  With -f:       Parse only the specified script file"
    echo ""
    echo "Examples:"
    echo "  $0                    # Parse all bash scripts in current directory"
    echo "  $0 -f script.sh       # Parse specific script"
    echo ""
}

# Main function
main() {
    local script_file=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--file)
                script_file="$2"
                shift 2
                ;;
            *)
                script_file="$1"
                shift
                ;;
        esac
    done
    
    # Initialize
    init_directories
    
    # Check GUI availability
    if ! check_gui_availability; then
        echo -e "${RED}Error: zenity is required for GUI mode${NC}"
        echo -e "${RED}Please install zenity: sudo apt install zenity${NC}"
        exit 1
    fi
    
    # If script file specified, parse it directly
    if [[ -n "$script_file" ]]; then
        if [[ ! -f "$script_file" ]]; then
            echo -e "${RED}Error: Script file not found: $script_file${NC}"
            exit 1
        fi
        
        SELECTED_TASKS=()
        
        # Clear tasks and parse single file
        TASKS=()
        TASK_DESCRIPTIONS=()
        TASK_COMMANDS=()
        TASK_FILES=()
        TASK_LINE_NUMBERS=()
        
        if parse_script_file "$script_file"; then
            while true; do
                local display_result
                display_tasks_gui
                display_result=$?
                
                if [[ $display_result -eq 0 ]]; then
                    # Tasks selected, execute them
                    local exec_result
                    execute_tasks_gui
                    exec_result=$?
                    if [[ $exec_result -ne 2 ]]; then
                        break
                    fi
                    # Clear selection for next iteration
                    SELECTED_TASKS=()
                elif [[ $display_result -eq 2 ]]; then
                    # Select All or Unselect All was clicked, redisplay dialog
                    continue
                else
                    # User cancelled or other error
                    break
                fi
            done
        fi
    else
        # Parse all bash executable files in root directory
        if parse_all_scripts; then
            while true; do
                local display_result
                display_tasks_gui
                display_result=$?
                
                if [[ $display_result -eq 0 ]]; then
                    # Tasks selected, execute them
                    local exec_result
                    execute_tasks_gui
                    exec_result=$?
                    if [[ $exec_result -ne 2 ]]; then
                        break
                    fi
                    # Clear selection for next iteration
                    SELECTED_TASKS=()
                elif [[ $display_result -eq 2 ]]; then
                    # Select All or Unselect All was clicked, redisplay dialog
                    continue
                else
                    # User cancelled or other error
                    break
                fi
            done
        fi
    fi
}

# Run main function
main "$@"
