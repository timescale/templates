#!/bin/bash

# WebTop - Network Traffic Monitor
# This script provides an easy way to start and stop the monitoring services

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default database connection string
DEFAULT_DB_URI="postgresql://postgres:password@0.0.0.0:5433/website_tracker"

# Function to anonymize database URI
anonymize_uri() {
  local uri=$1
  # Handle both postgres:// and postgresql:// formats
  # Replace username:password with ****:****
  echo "$uri" | sed -E 's|(postgres(ql)?://)[^:]+:[^@]+@|\1****:****@|'
}

# Function to get database URI
get_db_uri() {
  if [ -n "$DB_URI" ]; then
    echo "$DB_URI"
  else
    echo "$DEFAULT_DB_URI"
  fi
}

# Function to check database connection
check_db_connection() {
  local uri=$1
  if ! psql "$uri" -c '\q' >/dev/null 2>&1; then
    echo -e "${RED}Error: Could not connect to database at $uri${NC}"
    return 1
  fi
  return 0
}

# Function to display usage
show_usage() {
  echo -e "${YELLOW}WebTop${NC} - Network Traffic Monitor"
  echo ""
  echo "Usage: $0 [command] [options]"
  echo ""
  echo "Commands:"
  echo "  start       - Start the monitoring services"
  echo "  stop        - Stop the monitoring services"
  echo "  restart     - Restart the monitoring services"
  echo "  monitor     - Show monitoring dashboard (combines status and patterns)"
  echo "  setup       - Set up traffic patterns for testing"
  echo "  setup-db    - Run the main database setup script"
  echo "  stop        - Stop traffic pattern generation"
  echo "  reset       - Reset the database (clear all data)"
  echo "  stats       - Run advanced statistical analysis"
  echo "  psql        - Connect to the database with psql (start hacking!)"
  echo "  help        - Show this help message"
  echo ""
  echo "Options:"
  echo "  --uri URI   - Use custom database URI (e.g., postgresql://user:pass@host:port/db)"
  echo ""
  echo "Examples:"
  echo "  $0 start --uri postgresql://user:pass@localhost:5432/mydb"
  echo "  $0 monitor --uri \$demos_uri"
  echo "  $0 psql    - Connect to the database and start experimenting"
  echo ""
  echo "Proper order of operations:"
  echo "  $0 start"
  echo "  $0 setup-db"
  echo "  $0 setup"
  echo "  $0 monitor"
  echo "  $0 stop"
  echo "Later, when you're done:"
  echo "  $0 reset"
  echo ""
}

# Function to start services
start_services() {
  local db_uri=$(get_db_uri)
  
  echo -e "${GREEN}Starting WebTop services...${NC}"
  echo -e "${YELLOW}Note: This requires Docker privileges${NC}"
  
  # Start Docker services
  docker compose up -d
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start services${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}Services started successfully!${NC}"
  
  # Wait for database to be ready
  echo -e "${YELLOW}Waiting for database to be ready...${NC}"
  sleep 5
  
  # Check database connection
  if ! check_db_connection "$db_uri"; then
    echo -e "${RED}Error: Database not ready. Please check Docker logs.${NC}"
    exit 1
  fi
  
  # Run the pipeline script
  echo -e "${GREEN}Running main pipeline script...${NC}"
  psql "$db_uri" -f sql/setup/pipeline.sql
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to run pipeline script${NC}"
    exit 1
  fi
  
  # Run the main setup script
  echo -e "${GREEN}Running main setup script...${NC}"
  psql "$db_uri" -f sql/setup/main.sql
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Main setup script completed successfully!${NC}"
    echo -e "Use ${YELLOW}$0 monitor${NC} to see real-time statistics"
  else
    echo -e "${RED}Error: Failed to run main setup script${NC}"
    exit 1
  fi
}

# Function to stop services
stop_services() {
  local db_uri=$(get_db_uri)
  
  # Only stop Docker services if using default database
  if [ "$db_uri" = "$DEFAULT_DB_URI" ]; then
    echo -e "${GREEN}Stopping WebTop services...${NC}"
    docker compose down
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Services stopped successfully!${NC}"
    else
      echo -e "${RED}Error: Failed to stop services${NC}"
      exit 1
    fi
  else
    echo -e "${YELLOW}Using external database - no services to stop${NC}"
  fi
}

# Function to show unified monitoring dashboard
show_monitoring_dashboard() {
  local db_uri=$(get_db_uri)
  local anonymized_uri=$(anonymize_uri "$db_uri")
  
  # Check database connection
  if ! check_db_connection "$db_uri"; then
    exit 1
  fi
  
  clear
  
  echo -e "${BLUE}=========================================${NC}"
  echo -e "${GREEN}           WebTop Dashboard             ${NC}"
  echo -e "${BLUE}=========================================${NC}"
  echo ""
  
  # Show service status
  if [ "$db_uri" = "$DEFAULT_DB_URI" ]; then
    echo -e "${YELLOW}Service Status:${NC}"
    docker compose ps
    echo ""
  else
    echo -e "${YELLOW}Database Status:${NC}"
    echo -e "Connected to: $anonymized_uri"
    echo ""
  fi

  echo -e "${YELLOW}Top Domains (Last Hour):${NC}"
  psql "$db_uri" -c \
    "SELECT domain, COUNT(*) AS hits FROM logs 
      WHERE time > NOW() - INTERVAL '1 hour' 
      GROUP BY domain ORDER BY hits DESC LIMIT 10;"
  
  echo ""
  
  echo -e "${YELLOW}Recent Activity:${NC}"
  psql "$db_uri" -c \
    "SELECT domain, time FROM logs 
      ORDER BY time DESC LIMIT 5;"
  
  echo ""
  
  echo -e "${YELLOW}Statistics:${NC}"
  psql "$db_uri" -c \
    "SELECT 'Total Domains' AS stat, COUNT(DISTINCT domain)::text AS value FROM logs
      UNION ALL
      SELECT 'Total Captures' AS stat, COUNT(*)::text AS value FROM logs
      UNION ALL
      SELECT 'Earliest Capture' AS stat, to_char(MIN(now() - time), 'DD HH24:MI:SS') AS value FROM logs
      UNION ALL
      SELECT 'Latest Capture' AS stat, to_char(MAX(now() - time), 'DD HH24:MI:SS') AS value FROM logs;"

  echo ""
  echo -e "${BLUE}=========================================${NC}"
  echo -e "${YELLOW}Press Ctrl+C to exit dashboard${NC}"
  echo -e "${BLUE}=========================================${NC}"
  
  # Keep updating
  sleep 5
  clear
  show_monitoring_dashboard
}

# Function to reset database
reset_database() {
  local db_uri=$(get_db_uri)
  
  # Check database connection
  if ! check_db_connection "$db_uri"; then
    exit 1
  fi
  
  echo -e "${YELLOW}Warning: This will delete all captured data!${NC}"
  read -p "Are you sure you want to continue? (y/n) " -n 1 -r
  echo ""
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Resetting database...${NC}"
    
    # Run the reset script
    psql "$db_uri" -f sql/maintenance/reset.sql
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Database reset successfully!${NC}"
    else
      echo -e "${RED}Error: Failed to reset database${NC}"
      exit 1
    fi
  else
    echo -e "${BLUE}Reset cancelled.${NC}"
  fi
}

# Function to set up traffic patterns
setup_traffic_patterns() {
  local db_uri=$(get_db_uri)
  
  # Check database connection
  if ! check_db_connection "$db_uri"; then
    exit 1
  fi
  
  echo -e "${GREEN}Setting up traffic patterns for testing...${NC}"
  
  # Run the setup traffic patterns script
  psql "$db_uri" -f sql/setup/setup_traffic_patterns.sql
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Traffic patterns set up successfully!${NC}"
  else
    echo -e "${RED}Error: Failed to set up traffic patterns${NC}"
    exit 1
  fi
}

# Function to stop traffic patterns
stop_traffic_patterns() {
  local db_uri=$(get_db_uri)
  
  # Check database connection
  if ! check_db_connection "$db_uri"; then
    exit 1
  fi
  
  echo -e "${GREEN}Stopping traffic pattern generation...${NC}"
  
  # Run the stop traffic patterns script
  psql "$db_uri" -f sql/setup/stop_traffic_patterns.sql
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Traffic pattern generation stopped successfully!${NC}"
  else
    echo -e "${RED}Error: Failed to stop traffic pattern generation${NC}"
    exit 1
  fi
}

# Function to run main database setup
run_main_setup() {
  local db_uri=$(get_db_uri)
  
  # Check database connection
  if ! check_db_connection "$db_uri"; then
    exit 1
  fi
  
  echo -e "${GREEN}Running main database setup script...${NC}"
  
  # Run the main setup script
  psql "$db_uri" -f sql/setup/main.sql
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Main setup script completed successfully!${NC}"
    echo -e "Use ${YELLOW}$0 monitor${NC} to see real-time statistics"
  else
    echo -e "${RED}Error: Failed to run main setup script${NC}"
    exit 1
  fi
}

# Function to run statistical analysis
run_statistical_analysis() {
  local db_uri=$(get_db_uri)
  
  # Check database connection
  if ! check_db_connection "$db_uri"; then
    exit 1
  fi
  
  echo -e "${GREEN}Running advanced statistical analysis...${NC}"
  
  # Run the statistical analysis script
  psql "$db_uri" -f sql/analysis/statistical_analysis.sql
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Statistical analysis completed successfully!${NC}"
  else
    echo -e "${RED}Error: Failed to run statistical analysis${NC}"
    exit 1
  fi
}

# Function to restart services
restart_services() {
  local db_uri=$(get_db_uri)
  
  echo -e "${GREEN}Restarting WebTop services...${NC}"
  
  # Stop services
  docker compose down
  
  # Start services
  docker compose up -d
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to restart services${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}Services restarted successfully!${NC}"
  
  # Wait for database to be ready
  echo -e "${YELLOW}Waiting for database to be ready...${NC}"
  sleep 5
  
  # Check database connection
  if ! check_db_connection "$db_uri"; then
    echo -e "${RED}Error: Database not ready. Please check Docker logs.${NC}"
    exit 1
  fi
  
  # Run the pipeline script
  echo -e "${GREEN}Running main pipeline script...${NC}"
  psql "$db_uri" -f sql/setup/pipeline.sql
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to run pipeline script${NC}"
    exit 1
  fi
  
  # Run the main setup script
  echo -e "${GREEN}Running main setup script...${NC}"
  psql "$db_uri" -f sql/setup/main.sql
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Main setup script completed successfully!${NC}"
    echo -e "Use ${YELLOW}$0 monitor${NC} to see real-time statistics"
  else
    echo -e "${RED}Error: Failed to run main setup script${NC}"
    exit 1
  fi
}

# Function to connect to database with psql
connect_psql() {
  local db_uri=$(get_db_uri)
  
  # Check database connection
  if ! check_db_connection "$db_uri"; then
    exit 1
  fi
  
  echo -e "${GREEN}Connecting to database...${NC}"
  echo -e "${YELLOW}Tip: Try these commands to get started:${NC}"
  echo -e "  ${BLUE}\\dt${NC} - List all tables"
  echo -e "  ${BLUE}\\df${NC} - List all functions"
  echo -e "  ${BLUE}SELECT * FROM monitor_traffic_patterns();${NC} - View AI domain traffic"
  echo -e "  ${BLUE}SELECT * FROM logs LIMIT 5;${NC} - View recent logs"
  echo ""
  
  # Connect to database
  psql "$db_uri"
}

# Parse command line arguments
DB_URI=""
COMMAND=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --uri)
      DB_URI="$2"
      shift 2
      ;;
    start|stop|restart|monitor|setup|setup-db|reset|stats|psql|help)
      COMMAND="$1"
      shift
      ;;
    *)
      echo -e "${RED}Error: Unknown option '$1'${NC}"
      show_usage
      exit 1
      ;;
  esac
done

# Main script execution
if [ -z "$COMMAND" ]; then
  show_usage
  exit 0
fi

# Process commands
case "$COMMAND" in
  start)
    start_services
    ;;
  stop)
    stop_services
    ;;
  restart)
    restart_services
    ;;
  monitor)
    show_monitoring_dashboard
    ;;
  setup)
    setup_traffic_patterns
    ;;
  setup-db)
    run_main_setup
    ;;
  reset)
    reset_database
    ;;
  stats)
    run_statistical_analysis
    ;;
  psql)
    connect_psql
    ;;
  help)
    show_usage
    ;;
  *)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}"
    show_usage
    exit 1
    ;;
esac 
