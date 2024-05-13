# Timescale Templates

Template to get started with TimescaleDB for financial and IoT time-series data.

Every folder has its own setup and usage:

* [finance](./finance/README.md) folder contains market data processing.
* [sensors](./sensors/README.md) folder contains IoT data processing.

## What is TimescaleDB?

TimescaleDB is an open-source database designed to make SQL scalable for time-series data. It's optimized for fast ingest and complex queries, making it ideal for finance, IoT, DevOps, and other time-series data applications.

## Finance Market Data

This setup is ideal for anyone working with financial time-series data in TimescaleDB, such as:

- Financial analysts tracking market trends.
- Data scientists conducting financial research.
- Fintech applications requiring real-time market data analysis.


### Prerequisites

To use this repository, you need to have TimescaleDB installed. If you haven't already,
you can find detailed installation instructions on the
[Timescale installation pages](https://docs.timescale.com/latest/getting-started/installation).

Also, to use all the hyperfunctions available, we may also need the
[timescaledb-toolkit](https://docs.timescale.com/self-hosted/latest/tooling/install-toolkit/)
functions.

To fastest way to setup both extensions at once on premise is with [timescaledb-ha docker](https://hub.docker.com/r/timescale/timescaledb-ha) image.

### Setup and Usage

This is a main repository with folders that contains different scenarios. The
setup and usage is inside each folder. For now we have:

The [finance](./finance/README.md) setup your market data processing with:

- A `ticks` hypertable for efficient storage and querying of tick data.
- Continuous aggregates for generating candlesticks.
- Compression and retention policies.
- Utilities for tracking symbol pairs and last prices.

The [sensors](./sensors/README.md) setup your IoT data processing with:
- A configurable system that you can define what is your hypertable name and other details of your data.
- Dynamic SQL for generating Hierarchical Continuous Aggregates.
- Compression and retention policies.
- Example of how to use the system with a sample dataset and with data simulator
    functions generating data using background workers.

## Contributing

Your contributions are welcome! Feel free to fork this repository, make changes, and submit pull requests. If you have any suggestions or need support, join the `#tech-design` channel on our [slack](https://timescaledb.slack.com).

## Feedback and Support

For feedback and support, please join our [Slack community](https://www.timescale.com/community/). Your input helps us improve and expand this project.

📺[Youtube Playlist][youtube] with all presentations about this project.

If you need any extra detail, feel free to reach out `jonatas@timescale.com` or
or join our [timescaledb Slack](https://timescaledb.slack.com/).


[ical]: https://timescale.zoom.us/webinar/tJcocu-qqTMuG9CfVhEQueFx0mcqY1pb8eNl/ics?icsToken=98tyKuCrqz4sGNOdtBiDRowqGY_4M-rwtlxbjfp-mintJhFGZyXuZu9BI4suANqI
[youtube]: https://www.youtube.com/playlist?list=PLsceB9ac9MHStasIKKOs-jTWyCAXybfbc
