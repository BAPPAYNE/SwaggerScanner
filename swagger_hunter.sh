#!/bin/bash

# Author: coffinxp
# Tool: Swagger Hunter - A tool to find and analyze Swagger/OpenAPI instances.

# --- Colors and Banner ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

display_banner() {
    echo -e "${BLUE}"
    echo "  _________              __                       __  __                "
    echo " /   _____/____    _____/  |_  ______ ___________|  |/  /______  ____   "
    echo " \_____  \\__  \  /    \   __\/  ___// __ \_  __ \  '  / \_  __ \/  _ \  "
    echo " /        \/ __ \|   |  \  |  \___ \\  ___/|  | \/  .  \ |  | \(  <_> ) "
    echo "/_______  (____  /___|  /__| /____  >\___  >__|  |__|\__\|__|   \____/  "
    echo "        \/     \/     \/          \/     \/                            "
    echo -e "                                     ${YELLOW}Author: coffinxp${NC}"
    echo ""
}

# --- Usage Information ---
usage() {
    display_banner
    echo -e "${YELLOW}A tool to find exposed Swagger/OpenAPI instances using Google Dorks.${NC}"
    echo ""
    echo -e "${GREEN}USAGE:${NC}"
    echo "  ./swagger_hunter.sh [OPTIONS]"
    echo ""
    echo -e "${GREEN}MODES:${NC}"
    echo "  - Interactive Mode: Run without any arguments to get a menu."
    echo "    ./swagger_hunter.sh"
    echo ""
    echo "  - Command-Line Mode: Use flags to run scans directly."
    echo ""
    echo -e "${GREEN}OPTIONS:${NC}"
    echo "  Target Selection (mutually exclusive):"
    echo "    -u, --url <domain>      Specify a single target domain to scan."
    echo "    -f, --file <filepath>     Specify a file containing a list of target domains."
    echo ""
    echo "  Dork Selection:"
    echo "    -d, --dork <dork_string>  Use a single custom Google dork."
    echo "    --dork-file <filepath>    Use a file containing a list of custom dorks."
    echo "                              (If no dork option is used, built-in dorks are run)."
    echo ""
    echo "  Output & Control:"
    echo "    -l, --limit <number>      Limit the number of results per dork."
    echo "    -o, --output <filepath>   Specify the output file (Default: swagger_results.txt)."
    echo "    -h, --help                Display this help message."
    echo ""
    echo -e "${GREEN}EXAMPLES:${NC}"
    echo "  ./swagger_hunter.sh -u example.com -l 20"
    echo "  ./swagger_hunter.sh -f domains.txt -o results.txt"
    echo "  ./swagger_hunter.sh -u example.com --dork 'intitle:\"Swagger UI\"'"
    echo "  ./swagger_hunter.sh -f domains.txt --dork-file my_dorks.txt"
    exit 1
}

# --- Dependency Check ---
check_dependencies() {
    echo -e "${YELLOW}[*] Checking for required tools...${NC}"
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}[-] Python 3 is not installed. Please install it.${NC}"
        exit 1
    fi
    python3 -c "import googlesearch" &> /dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}[-] Python 'googlesearch-python' library not found. Please run: pip3 install googlesearch-python${NC}"
        exit 1
    fi
    echo -e "${GREEN}[+] Dependencies are satisfied.${NC}"
}

# --- Non-Interactive Scan Function ---
run_scan_cli() {
    # Prepare the Python script arguments
    PYTHON_ARGS=""
    if [ -n "$LIMIT" ]; then PYTHON_ARGS+="--limit \"$LIMIT\" "; fi
    if [ -n "$OUTPUT" ]; then PYTHON_ARGS+="--output \"$OUTPUT\" "; fi
    if [ -n "$DORK" ]; then PYTHON_ARGS+="--dork \"$DORK\" "; fi
    if [ -n "$DORK_FILE" ]; then PYTHON_ARGS+="--dork-file \"$DORK_FILE\" "; fi

    # Clear output file before starting a new scan batch
    if [ -n "$OUTPUT" ]; then > "$OUTPUT"; fi

    display_banner
    if [ -n "$URL" ]; then
        echo -e "${YELLOW}[*] Scanning single target: ${URL}${NC}"
        python3 google_dorker.py --domain "$URL" $PYTHON_ARGS
    elif [ -n "$FILE" ]; then
        echo -e "${YELLOW}[*] Scanning targets from file: ${FILE}${NC}"
        while IFS= read -r domain || [[ -n "$domain" ]]; do
            if [ -n "$domain" ]; then
                echo -e "\n${BLUE}--- Scanning: $domain ---${NC}"
                # Add append flag for subsequent runs in the same file
                python3 google_dorker.py --domain "$domain" $PYTHON_ARGS --append
            fi
        done < "$FILE"
    else
        echo -e "${YELLOW}[*] Running a broad scan (no target domain specified)${NC}"
        python3 google_dorker.py $PYTHON_ARGS
    fi
    echo -e "\n${GREEN}[+] Scan complete. Results saved to '${OUTPUT:-swagger_results.txt}'.${NC}"
}

# --- Interactive Scan Function ---
run_scan_interactive() {
    echo -e "\n${BLUE}=======================================${NC}"
    echo -e "${YELLOW}  Finding Exposed APIs via Google Dorks${NC}"
    echo -e "${BLUE}=======================================${NC}"

    read -p "Enter the target website (e.g., nasa.gov) or press Enter to search broadly: " target_site
    read -p "Enter the number of results per dork (or press Enter for all): " result_limit
    output_file="swagger_interactive_results.txt"

    echo -e "${YELLOW}[*] Starting scan... Results will be saved to '${output_file}'${NC}"
    
    python3 google_dorker.py --domain "${target_site}" --limit "${result_limit}" --output "${output_file}"

    echo -e "\n${GREEN}[+] Scan complete. Results saved to '${output_file}'.${NC}"
}

# --- Main Menu for Interactive Mode ---
main_menu() {
    while true; do
        clear
        display_banner
        echo -e "${YELLOW}Select a module to run:${NC}"
        echo "  1) Finding Exposed APIs: Google Dorks"
        # ... other options ...
        echo "  0) Exit"
        read -p "Enter your choice: " choice

        case $choice in
            1) run_scan_interactive; read -p $'\nPress Enter to return...' ;;
            0) echo -e "${GREEN}Happy Hunting!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}


# --- SCRIPT ENTRY POINT ---

# If no arguments are provided, run interactively.
if [ "$#" -eq 0 ]; then
    check_dependencies
    main_menu
    exit 0
fi

# Parse Command-Line Arguments
URL=""
FILE=""
DORK=""
DORK_FILE=""
LIMIT=""
OUTPUT="swagger_results.txt"

while [[ "$#" -gt 0 ]]; do
    case $1 in
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

# Validate arguments
if [ -n "$URL" ] && [ -n "$FILE" ]; then
    echo -e "${RED}Error: Cannot use -u (--url) and -f (--file) at the same time.${NC}"
    usage
fi

check_dependencies
run_scan_cli