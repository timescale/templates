#!/bin/bash
# Installation script for Top Websites Tracker

# Configuration
PSQL_CMD=${PSQL_CMD:-"psql"}
DB_URI=${DB_URI:-"$local_uri"}

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Top Websites Tracker Installation ===${NC}"

# Check if psql is available
if ! command -v $PSQL_CMD &> /dev/null; then
    echo -e "${RED}Error: psql command not found${NC}"
    echo "Please install PostgreSQL client tools or set PSQL_CMD environment variable"
    exit 1
fi

# Check if DB_URI is set
if [ -z "$DB_URI" ]; then
    echo -e "${RED}Error: No database connection string provided${NC}"
    echo "Please set a connection string:"
    echo "export local_uri=\"postgresql://username:password@0.0.0.0:5432/mydatabase\""
    exit 1
fi

# Check if database connection is available
if ! $PSQL_CMD $DB_URI -c "SELECT 1" &> /dev/null; then
    echo -e "${RED}Error: Unable to connect to database${NC}"
    echo "Please check your connection string:"
    echo "export local_uri=\"postgresql://username:password@0.0.0.0:5432/mydatabase\""
    exit 1
fi

# Check if TimescaleDB is installed
if ! $PSQL_CMD $DB_URI -c "SELECT extname FROM pg_extension WHERE extname = 'timescaledb'" | grep -q timescaledb; then
    echo -e "${YELLOW}Warning: TimescaleDB extension not found in database${NC}"
    echo "Would you like to install the TimescaleDB extension now? (y/n)"
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo "Installing TimescaleDB extension..."
        $PSQL_CMD $DB_URI -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
    else
        echo -e "${RED}TimescaleDB is required. Installation aborted.${NC}"
        exit 1
    fi
fi

# Run the main script
echo -e "${YELLOW}Installing Top Websites Tracker...${NC}"
$PSQL_CMD $DB_URI -f main.sql

echo -e "${GREEN}Installation complete!${NC}"
echo "You can now use the Top Websites Tracker system."
echo ""
echo "Quick commands:"
echo "---------------"
echo -e "Generate test data:  ${YELLOW}$PSQL_CMD $DB_URI -c \"SELECT start_all_data_generation();\"${NC}"
echo -e "View top websites:   ${YELLOW}$PSQL_CMD $DB_URI -c \"SELECT * FROM top_websites_report LIMIT 10;\"${NC}"
echo -e "Run maintenance:     ${YELLOW}$PSQL_CMD $DB_URI -f maintenance-routine.sql${NC}"
echo ""
echo "Enjoy tracking your top websites!" 