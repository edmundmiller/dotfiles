#!/bin/bash
# Master test runner for all open action tests

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track overall results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Function to run a test suite
run_test_suite() {
    local suite_name="$1"
    local script_path="$2"
    
    echo
    printf "${BLUE}===========================================${NC}\n"
    printf "${BLUE}Running Test Suite: $suite_name${NC}\n"
    printf "${BLUE}===========================================${NC}\n"
    
    TOTAL_SUITES=$((TOTAL_SUITES + 1))
    
    if bash "$script_path"; then
        printf "${GREEN}✓ $suite_name PASSED${NC}\n"
        PASSED_SUITES=$((PASSED_SUITES + 1))
        return 0
    else
        printf "${RED}✗ $suite_name FAILED${NC}\n"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        return 1
    fi
}

# Function to check if the open script exists
check_open_script() {
    if [[ ! -f "$SCRIPT_DIR/../open" ]]; then
        printf "${YELLOW}Warning: open script not found at $SCRIPT_DIR/../open${NC}\n"
        printf "${YELLOW}Some integration tests may fail.${NC}\n"
        echo
        return 1
    fi
    return 0
}

# Main execution
main() {
    echo "Todo.txt Open Action - Test Suite Runner"
    echo "========================================"
    echo
    
    # Check for the open script
    check_open_script
    
    # Run all test suites
    run_test_suite "URL Parsing Unit Tests" "$SCRIPT_DIR/test_url_parsing.sh"
    run_test_suite "Integration Tests" "$SCRIPT_DIR/test_integration.sh"  
    run_test_suite "Edge Cases & Error Handling" "$SCRIPT_DIR/test_edge_cases.sh"
    
    # Final summary
    echo
    printf "${BLUE}=========================================${NC}\n"
    printf "${BLUE}FINAL TEST SUMMARY${NC}\n"
    printf "${BLUE}=========================================${NC}\n"
    echo "Total Test Suites: $TOTAL_SUITES"
    printf "Passed: ${GREEN}$PASSED_SUITES${NC}\n"
    
    if [[ $FAILED_SUITES -gt 0 ]]; then
        printf "Failed: ${RED}$FAILED_SUITES${NC}\n"
        echo
        printf "${RED}❌ Some test suites failed!${NC}\n"
        exit 1
    else
        echo "Failed: $FAILED_SUITES"
        echo
        printf "${GREEN}🎉 All test suites passed!${NC}\n"
        exit 0
    fi
}

# Make test scripts executable
chmod +x "$SCRIPT_DIR"/*.sh

# Run main function
main "$@"
