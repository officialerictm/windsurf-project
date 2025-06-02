# ==============================================================================
# Model Registry
# ==============================================================================
# Description: Management of available AI models and their metadata
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,04_network/download.sh
# ==============================================================================

# Model registry - maps model IDs to information
declare -A MODEL_REGISTRY
declare -A MODEL_URLS
declare -A MODEL_CHECKSUMS
declare -A MODEL_SIZES
declare -A MODEL_REQUIREMENTS

# Initialize the model registry
init_model_registry() {
    log_message "INFO" "Initializing model registry"
    
    # Reset model arrays
    MODEL_REGISTRY=()
    MODEL_URLS=()
    MODEL_CHECKSUMS=()
    MODEL_SIZES=()
    MODEL_REQUIREMENTS=()
    
    # Register the supported models
    # Format: register_model ID NAME DESCRIPTION [SIZE_MB] [URL] [CHECKSUM] [REQUIREMENTS]
    
    # LLaMA 3 8B
    register_model "llama3-8b" "Meta LLaMA 3 8B" "General purpose, low resource LLM with strong performance" \
        "4800" \
        "https://huggingface.co/meta-llama/Meta-Llama-3-8B-Instruct/resolve/main/consolidated.00.pth" \
        "e51fd235"
    
    # LLaMA 3 70B
    register_model "llama3-70b" "Meta LLaMA 3 70B" "High performance LLM for complex reasoning tasks" \
        "41500" \
        "https://huggingface.co/meta-llama/Meta-Llama-3-70B-Instruct/resolve/main/consolidated.00.pth" \
        "3e00bbb2" \
        "RAM:32GB,GPU:24GB"
    
    # Mistral 7B
    register_model "mistral-7b" "Mistral 7B" "Efficient, strong instruction following model" \
        "4300" \
        "https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.2/resolve/main/consolidated.00.pth" \
        "9f43825c"
    
    # Mixtral 8x7B
    register_model "mixtral-8x7b" "Mixtral 8x7B" "Mixture of experts, best for complex tasks" \
        "26500" \
        "https://huggingface.co/mistralai/Mixtral-8x7B-Instruct-v0.1/resolve/main/consolidated.00.pth" \
        "21e8d6a5" \
        "RAM:24GB,GPU:16GB"
    
    # Claude Instant
    register_model "claude-instant" "Anthropic Claude Instant" "Fast, efficient chat model for everyday use" \
        "5200" \
        "https://anthropic.api/models/claude-instant" \
        "" \
        "API_KEY:anthropic"
    
    # Claude 3 Opus
    register_model "claude-3-opus" "Anthropic Claude 3 Opus" "Extremely powerful reasoning and instruction following" \
        "0" \
        "https://anthropic.api/models/claude-3-opus" \
        "" \
        "API_KEY:anthropic"
    
    # Gemma 7B
    register_model "gemma-7b" "Google Gemma 7B" "Efficient, balanced performance" \
        "4100" \
        "https://huggingface.co/google/gemma-7b-it/resolve/main/consolidated.00.pth" \
        "c72bf3a0"
    
    # Gemma 2B
    register_model "gemma-2b" "Google Gemma 2B" "Ultra-lightweight, mobile-friendly model" \
        "1300" \
        "https://huggingface.co/google/gemma-2b-it/resolve/main/consolidated.00.pth" \
        "fb5fe0de"
    
    log_message "INFO" "Model registry initialized with ${#MODEL_REGISTRY[@]} models"
}

# Register a model in the registry
register_model() {
    local id="$1"
    local name="$2"
    local description="$3"
    local size="${4:-0}"
    local url="${5:-}"
    local checksum="${6:-}"
    local requirements="${7:-}"
    
    MODEL_REGISTRY["$id"]="$name|$description"
    MODEL_URLS["$id"]="$url"
    MODEL_CHECKSUMS["$id"]="$checksum"
    MODEL_SIZES["$id"]="$size"
    MODEL_REQUIREMENTS["$id"]="$requirements"
    
    log_message "DEBUG" "Registered model: $id ($name)"
}

# Get model information by ID
get_model_info() {
    local id="$1"
    local field="${2:-name}"  # name, description, url, checksum, size, requirements
    
    # Check if model exists
    if [[ -z "${MODEL_REGISTRY[$id]}" ]]; then
        log_message "WARNING" "Model not found: $id"
        return 1
    fi
    
    # Parse model information
    local info="${MODEL_REGISTRY[$id]}"
    local name description
    IFS='|' read -r name description <<< "$info"
    
    # Return requested field
    case "$field" in
        name)
            echo "$name"
            ;;
        description)
            echo "$description"
            ;;
        url)
            echo "${MODEL_URLS[$id]}"
            ;;
        checksum)
            echo "${MODEL_CHECKSUMS[$id]}"
            ;;
        size)
            echo "${MODEL_SIZES[$id]}"
            ;;
        requirements)
            echo "${MODEL_REQUIREMENTS[$id]}"
            ;;
        *)
            log_message "WARNING" "Unknown field: $field"
            return 1
            ;;
    esac
    
    return 0
}

# Check if a model exists in the registry
model_exists() {
    local id="$1"
    
    if [[ -n "${MODEL_REGISTRY[$id]}" ]]; then
        return 0
    else
        return 1
    fi
}

# List all available models
list_available_models() {
    local format="${1:-table}"  # table, list, or json
    
    log_message "INFO" "Listing available models in format: $format"
    
    case "$format" in
        table)
            # Print header
            printf "%-15s %-30s %-10s %s\n" "ID" "NAME" "SIZE" "DESCRIPTION"
            printf "%-15s %-30s %-10s %s\n" "---------------" "------------------------------" "----------" "------------------------------------"
            
            # Print each model
            for id in "${!MODEL_REGISTRY[@]}"; do
                local name description
                IFS='|' read -r name description <<< "${MODEL_REGISTRY[$id]}"
                local size="${MODEL_SIZES[$id]}"
                
                # Format size
                if [[ $size -ge 1024 ]]; then
                    size="$(echo "scale=1; $size / 1024" | bc) GB"
                else
                    size="$size MB"
                fi
                
                printf "%-15s %-30s %-10s %s\n" "$id" "$name" "$size" "$description"
            done
            ;;
        
        list)
            # Print each model on a line
            for id in "${!MODEL_REGISTRY[@]}"; do
                local name description
                IFS='|' read -r name description <<< "${MODEL_REGISTRY[$id]}"
                echo "$id: $name - $description"
            done
            ;;
        
        json)
            # Print as JSON
            echo "{"
            echo "  \"models\": ["
            
            local first=true
            for id in "${!MODEL_REGISTRY[@]}"; do
                if [[ "$first" != "true" ]]; then
                    echo ","
                fi
                first=false
                
                local name description
                IFS='|' read -r name description <<< "${MODEL_REGISTRY[$id]}"
                local size="${MODEL_SIZES[$id]}"
                local requirements="${MODEL_REQUIREMENTS[$id]}"
                
                echo -n "    {"
                echo -n "\"id\":\"$id\","
                echo -n "\"name\":\"$name\","
                echo -n "\"description\":\"$description\","
                echo -n "\"size\":$size,"
                echo -n "\"requirements\":\"$requirements\""
                echo -n "}"
            done
            
            echo ""
            echo "  ]"
            echo "}"
            ;;
        
        *)
            log_message "WARNING" "Unknown format: $format"
            return 1
            ;;
    esac
    
    return 0
}

# Filter models based on system requirements
filter_models_by_requirements() {
    local ram="${1:-0}"  # Available RAM in GB
    local gpu="${2:-0}"  # Available GPU memory in GB
    local api_keys="${3:-}"  # Available API keys (comma-separated)
    
    log_message "INFO" "Filtering models by requirements: RAM=${ram}GB, GPU=${gpu}GB, API keys: $api_keys"
    
    # Create array for API keys
    local -a available_api_keys
    IFS=',' read -ra available_api_keys <<< "$api_keys"
    
    # Print header
    printf "%-15s %-30s %-10s %s\n" "ID" "NAME" "SIZE" "REQUIREMENTS"
    printf "%-15s %-30s %-10s %s\n" "---------------" "------------------------------" "----------" "------------------------------------"
    
    # Check each model
    for id in "${!MODEL_REGISTRY[@]}"; do
        local requirements="${MODEL_REQUIREMENTS[$id]}"
        local meets_requirements=true
        
        # Check RAM requirements
        if [[ "$requirements" =~ RAM:([0-9]+)GB ]]; then
            local required_ram="${BASH_REMATCH[1]}"
            if [[ $ram -lt $required_ram ]]; then
                meets_requirements=false
            fi
        fi
        
        # Check GPU requirements
        if [[ "$requirements" =~ GPU:([0-9]+)GB ]]; then
            local required_gpu="${BASH_REMATCH[1]}"
            if [[ $gpu -lt $required_gpu ]]; then
                meets_requirements=false
            fi
        fi
        
        # Check API key requirements
        if [[ "$requirements" =~ API_KEY:([a-z0-9_]+) ]]; then
            local required_api_key="${BASH_REMATCH[1]}"
            local has_api_key=false
            
            for key in "${available_api_keys[@]}"; do
                if [[ "$key" == "$required_api_key" ]]; then
                    has_api_key=true
                    break
                fi
            done
            
            if [[ "$has_api_key" != "true" ]]; then
                meets_requirements=false
            fi
        fi
        
        # Only print if meets requirements
        if [[ "$meets_requirements" == "true" ]]; then
            local name description
            IFS='|' read -r name description <<< "${MODEL_REGISTRY[$id]}"
            local size="${MODEL_SIZES[$id]}"
            
            # Format size
            if [[ $size -ge 1024 ]]; then
                size="$(echo "scale=1; $size / 1024" | bc) GB"
            else
                size="$size MB"
            fi
            
            printf "%-15s %-30s %-10s %s\n" "$id" "$name" "$size" "$requirements"
        fi
    done
    
    return 0
}

# Select a model with interactive menu
select_model() {
    local ram="${1:-0}"  # Available RAM in GB
    local gpu="${2:-0}"  # Available GPU memory in GB
    local api_keys="${3:-}"  # Available API keys (comma-separated)
    
    log_message "INFO" "Selecting model with requirements: RAM=${ram}GB, GPU=${gpu}GB, API keys: $api_keys"
    
    # Create array for API keys
    local -a available_api_keys
    IFS=',' read -ra available_api_keys <<< "$api_keys"
    
    # Create arrays for compatible models
    local -a compatible_ids
    local -a compatible_names
    local -a compatible_descriptions
    local -a compatible_sizes
    
    # Filter models by requirements
    for id in "${!MODEL_REGISTRY[@]}"; do
        local requirements="${MODEL_REQUIREMENTS[$id]}"
        local meets_requirements=true
        
        # Check RAM requirements
        if [[ "$requirements" =~ RAM:([0-9]+)GB ]]; then
            local required_ram="${BASH_REMATCH[1]}"
            if [[ $ram -lt $required_ram ]]; then
                meets_requirements=false
            fi
        fi
        
        # Check GPU requirements
        if [[ "$requirements" =~ GPU:([0-9]+)GB ]]; then
            local required_gpu="${BASH_REMATCH[1]}"
            if [[ $gpu -lt $required_gpu ]]; then
                meets_requirements=false
            fi
        fi
        
        # Check API key requirements
        if [[ "$requirements" =~ API_KEY:([a-z0-9_]+) ]]; then
            local required_api_key="${BASH_REMATCH[1]}"
            local has_api_key=false
            
            for key in "${available_api_keys[@]}"; do
                if [[ "$key" == "$required_api_key" ]]; then
                    has_api_key=true
                    break
                fi
            done
            
            if [[ "$has_api_key" != "true" ]]; then
                meets_requirements=false
            fi
        fi
        
        # Add to compatible models if meets requirements
        if [[ "$meets_requirements" == "true" ]]; then
            local name description
            IFS='|' read -r name description <<< "${MODEL_REGISTRY[$id]}"
            local size="${MODEL_SIZES[$id]}"
            
            compatible_ids+=("$id")
            compatible_names+=("$name")
            compatible_descriptions+=("$description")
            compatible_sizes+=("$size")
        fi
    done
    
    # Check if any compatible models found
    if [[ ${#compatible_ids[@]} -eq 0 ]]; then
        log_message "WARNING" "No compatible models found for your system"
        echo -e "${RED}No compatible models found for your system.${NC}"
        echo "Consider upgrading your hardware or adding API keys."
        return 1
    fi
    
    # Print header
    echo -e "${CYAN}Compatible AI Models for Your System${NC}"
    echo ""
    
    # Show models with numbers
    for i in "${!compatible_ids[@]}"; do
        local id="${compatible_ids[$i]}"
        local name="${compatible_names[$i]}"
        local description="${compatible_descriptions[$i]}"
        local size="${compatible_sizes[$i]}"
        
        # Format size
        if [[ $size -ge 1024 ]]; then
            size="$(echo "scale=1; $size / 1024" | bc) GB"
        else
            size="$size MB"
        fi
        
        echo -e "${BOLD}$((i+1)). ${GREEN}${name}${NC} (${YELLOW}${size}${NC})"
        echo "   ${DIM}${description}${NC}"
        echo ""
    done
    
    # Get user selection
    local selection
    while true; do
        echo -n "Select a model (1-${#compatible_ids[@]}): "
        read -r selection
        
        if [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -le "${#compatible_ids[@]}" ]]; then
            local selected_id="${compatible_ids[$((selection-1))]}"
            log_message "INFO" "User selected model: $selected_id"
            echo "$selected_id"
            return 0
        else
            echo -e "${RED}Invalid selection.${NC} Please try again."
        fi
    done
}

# Initialize the model registry
init_model_registry
