# Timescale Templates

This project is a Wor kin progress
This project is dedicated to providing tools and workflows for effectively
start with Timescale without being too worried about the initial configs.

The idea is just make a first opinionated version based on experts in our
community.

This is a work in progress and we're starting with processing financial data using TimescaleDB.

## What is TimescaleDB?

TimescaleDB is an open-source database designed to make SQL scalable for time-series data. It's optimized for fast ingest and complex queries, making it ideal for finance, IoT, DevOps, and other time-series data applications.

## Features

This repository provides:

- A `ticks` hypertable for efficient storage and querying of tick data.
- Continuous aggregates for generating candlesticks.
- Utilities for tracking symbol pairs and last prices.

## Common Use Cases

This setup is ideal for anyone working with financial time-series data in TimescaleDB, such as:

- Financial analysts tracking market trends.
- Data scientists conducting financial research.
- Fintech applications requiring real-time market data analysis.

## Getting Started

### Prerequisites

To use this repository, you need to have TimescaleDB installed. If you haven't already, you can find detailed installation instructions on the [Timescale installation pages](https://docs.timescale.com/latest/getting-started/installation).

### Setup and Usage

This is a main repository with folders that contains different scenarios. The
setup and usage is inside each folder. For now we have:

* [finance](./finance/README.md) for finance market data processing.

## Contributing

Your contributions are welcome! Feel free to fork this repository, make changes, and submit pull requests. If you have any suggestions or need support, join the `#tech-design` channel on our [slack](https://timescaledb.slack.com).

## Feedback and Support

For feedback and support, please join our [Slack community](https://www.timescale.com/community/). Your input helps us improve and expand this project.

## Join us to build the finance discussions

This project is a Work In Progress and should be validated by the
[finance](./finance/) community to be production-ready.

We'll meet and have discussions [weekly on Thursdays, at 14:00 UTC][ical].

All sessions will be at **2PM UTC**.

Here are the upcoming sessions:

* Feb 22, 2024 - Walkthrough the framework and why the default choices
* Feb 29, 2024 - Hierarchical continuous aggregates for candlestick processing
* March 7, 2024  - Tracking last price and the trigger side effects'
* March 14, 2024  - Tracking pair correlation
* March 21, 2024  - Downsampling techniques
* March 28, 2024 - Compression and side effects

[Download calendar events locally][ical].

Or join directly from the zoom link:

https://timescale.zoom.us/j/93556278414?pwd=cmllSnhqb1NSdld2OG1GRDhkaGZUQT09

Meeting ID: 935 5627 8414 Passcode: timescale 


If you need any extra detail, feel free to reach out `jonatas@timescale.com` or
or join our [timescaledb Slack](https://timescaledb.slack.com/).



[ical]: https://timescale.zoom.us/webinar/tJcocu-qqTMuG9CfVhEQueFx0mcqY1pb8eNl/ics?icsToken=98tyKuCrqz4sGNOdtBiDRowqGY_4M-rwtlxbjfp-mintJhFGZyXuZu9BI4suANqI
