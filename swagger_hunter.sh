#!/bin/bash

# Author: BAPPAYNE
# Tool: Swagger Hunter - A tool to find and analyze Swagger/OpenAPI instances.

# --- Colors and Banner ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

display_banner() {
    cat << "EOF"
      _________                                            _________
 /   _____/_  _  _______     ____   ____   ___________/   _____/ ____ _____    ____   ____   ___________
 \_____  \\ \/ \/ /\__  \   / ___\ / ___\_/ __ \_  __ \_____  \_/ ___\\__  \  /    \ /    \_/ __ \_  __ \
 /        \\     /  / __ \_/ /_/  > /_/  >  ___/|  | \/        \  \___ / __ \|   |  \   |  \  ___/|  | \/
/_______  / \/\_/  (____  /\___  /\___  / \___  >__| /_______  /\___  >____  /___|  /___|  /\___  >__|
        \/              \//_____//_____/      \/             \/     \/     \/     \/     \/     \/
EOF
    echo -e "${YELLOW}Author: BAPPAYNE | Inspired by: CoffinXP${NC}"
}

usage() {
    echo -e "\n${YELLOW}A tool to find exposed Swagger/OpenAPI instances using Google's Official API.${NC}"
    echo -e "\n${GREEN}Credentials are loaded from 'config.yaml' by default.${NC}"
    echo -e "\n${GREEN}USAGE:${NC} ./swagger_hunter.sh [OPTIONS]"
    echo -e "\n${GREEN}MODES:${NC}"
    echo "  Interactive: ./swagger_hunter.sh"
    echo "  Command-Line: Use flags to run scans directly."
    echo -e "\n${GREEN}REQUIRED CREDENTIALS:${NC}"
    echo "  -k, --api-key <key>         (Optional) Override the API Key from config.yaml."
    echo "  -c, --cse-id <id>           (Optional) Override the CSE ID from config.yaml."
    echo -e "\n${GREEN}TARGETS:${NC}"
    echo "  -u, --url <domain>        Specify a single target domain (e.g., example.com)."
    echo "  -f, --file <filepath>       Specify a file with a list of domains."
    echo -e "\n${GREEN}DORKS & OUTPUT:${NC}"
    echo "  -d, --dork <dork>         Use a single custom Google dork."
    echo "  --dork-file <filepath>    Use a file with a list of custom dorks."
    echo "  -l, --limit <number>        Limit results per dork (Max 100, Default 10)."
    echo "  -o, --output <filepath>     Specify the output file (Default: swagger_results_api.txt)."
    echo "  -h, --help                  Display this help message."
    exit 1
}

check_dependencies() {
    echo -e "${YELLOW}[*] Checking for required tools...${NC}"
    if ! command -v python3 &> /dev/null; then echo -e "${RED}[-] Python 3 is not installed.${NC}"; exit 1; fi
    python3 -c "import googleapiclient" &> /dev/null
    if [ $? -ne 0 ]; then echo -e "${RED}[-] Google API Client not found. Run: pip install google-api-python-client${NC}"; exit 1; fi
    # Add dependency check for PyYAML
    python3 -c "import yaml" &> /dev/null
    if [ $? -ne 0 ]; then echo -e "${RED}[-] PyYAML library not found. Run: pip3 install pyyaml${NC}"; exit 1; fi
    echo -e "${GREEN}[+] Dependencies are satisfied.${NC}"
}

clean_domain() {
    local dirty_url=$1
    echo "$dirty_url" | sed -e 's|https\?://||' -e 's|/.*$||'
}

run_scan_cli() {

    local python_args=()
    [ -n "$API_KEY" ] && python_args+=(--api-key "$API_KEY")
    [ -n "$CSE_ID" ] && python_args+=(--cse-id "$CSE_ID")
    
    [ -n "$LIMIT" ] && python_args+=(--limit "$LIMIT")
    [ -n "$OUTPUT" ] && python_args+=(--output "$OUTPUT")
    [ -n "$DORK" ] && python_args+=(--dork "$DORK")
    [ -n "$DORK_FILE" ] && python_args+=(--dork-file "$DORK_FILE")

    [ -n "$OUTPUT" ] && > "$OUTPUT"

    display_banner
    if [ -n "$URL" ]; then
        CLEANED_URL=$(clean_domain "$URL")
        echo -e "${YELLOW}[*] Scanning single target: ${CLEANED_URL}${NC}"
        # Execute the python script, expanding the array safely
        python3 google_dorker.py --domain "$CLEANED_URL" "${python_args[@]}"
    elif [ -n "$FILE" ]; then
        echo -e "${YELLOW}[*] Scanning targets from file: ${FILE}${NC}"
        while IFS= read -r domain || [[ -n "$domain" ]]; do
            if [ -n "$domain" ]; then
                CLEANED_DOMAIN=$(clean_domain "$domain")
                echo -e "\n${BLUE}--- Scanning: $CLEANED_DOMAIN ---${NC}"
                # Execute for each domain, adding --append
                python3 google_dorker.py --domain "$CLEANED_DOMAIN" "${python_args[@]}" --append
            fi
        done < "$FILE"
    else
        echo -e "${YELLOW}[*] Running a broad scan (no target specified)${NC}"
        # Execute without a domain
        python3 google_dorker.py "${python_args[@]}"
    fi
    echo -e "\n${GREEN}[+] Scan complete. Results saved to '${OUTPUT:-swagger_results_api.txt}'.${NC}"
}

run_scan_interactive() {
    display_banner
    echo -e "${YELLOW}Credentials will be loaded from 'config.yaml'.${NC}"
    echo -e "\n${YELLOW}--- Scan Options ---${NC}"
    read -p "Enter target URL/Domain (or press Enter for broad scan): " target_input
    if [ -z "$api_key" ] || [ -z "$cse_id" ]; then
        echo -e "${RED}API Key and CSE ID cannot be empty.${NC}"; return
    fi
    
    echo -e "\n${YELLOW}--- Scan Options ---${NC}"
    read -p "Enter target URL/Domain (or press Enter for broad scan): " target_input
    read -p "Enter result limit per dork [Default: 10]: " result_limit
    output_file="swagger_interactive_results.txt"
    CLEANED_TARGET=$(clean_domain "$target_input")
    
    echo -e "${YELLOW}[*] Starting scan... Results will be saved to '${output_file}'${NC}"
    
    python3 google_dorker.py --domain "${CLEANED_TARGET}" --limit "${result_limit}" --output "${output_file}"
    
    echo -e "\n${GREEN}[+] Scan complete.${NC}"
}

# SCRIPT STARTING 
if [ "$#" -eq 0 ]; then
    check_dependencies
    run_scan_interactive
    exit 0
fi

# Initialize variables
URL=""
FILE=""
DORK=""
DORK_FILE=""
LIMIT=""
OUTPUT="swagger_results_api.txt"
API_KEY=""
CSE_ID=""

# Parse Command-Line Arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -k|--api-key) API_KEY="$2"; shift ;;
        -c|--cse-id) CSE_ID="$2"; shift ;;
        -u|--url) URL="$2"; shift ;;
        -f|--file) FILE="$2"; shift ;;
        -d|--dork) DORK="$2"; shift ;;
        --dork-file) DORK_FILE="$2"; shift ;;
        -l|--limit) LIMIT="$2"; shift ;;
        -o|--output) OUTPUT="$2"; shift ;;
        -h|--help) usage ;;
        *) echo -e "${RED}Unknown parameter: $1${NC}"; usage ;;
    esac
    shift
done

if [ -n "$URL" ] && [ -n "$FILE" ]; then
    echo -e "${RED}Error: Cannot use -u and -f at the same time.${NC}"; usage
fi

check_dependencies
run_scan_cli