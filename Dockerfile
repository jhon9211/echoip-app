# Stage 1: Build the echoip application
FROM golang:1.19-alpine AS builder
WORKDIR /src
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o /app/echoip ./cmd/echoip

# Stage 2: Download the GeoIP databases
FROM maxmindinc/geoipupdate:v4.10.0 AS geoip
ARG MAXMIND_ACCOUNT_ID
ARG MAXMIND_LICENSE_KEY
# Create the necessary directories and the configuration file
RUN mkdir -p /usr/local/etc/ /usr/share/GeoIP && \
    echo "AccountID ${MAXMIND_ACCOUNT_ID}" > /usr/local/etc/GeoIP.conf && \
    echo "LicenseKey ${MAXMIND_LICENSE_KEY}" >> /usr/local/etc/GeoIP.conf && \
    echo "EditionIDs GeoLite2-Country GeoLite2-City" >> /usr/local/etc/GeoIP.conf && \
    echo "DatabaseDirectory /usr/share/GeoIP" >> /usr/local/etc/GeoIP.conf
RUN geoipupdate

# Stage 3: Create the final, minimal image
FROM gcr.io/distroless/static-debian11
COPY --from=builder /app/echoip /echoip
COPY --from=builder /src/html /html
# Copy both downloaded databases
COPY --from=geoip /usr/share/GeoIP/GeoLite2-Country.mmdb /db/GeoLite2-Country.mmdb
COPY --from=geoip /usr/share/GeoIP/GeoLite2-City.mmdb /db/GeoLite2-City.mmdb

EXPOSE 8080

# Start the service and tell it where to find both database files
ENTRYPOINT ["/echoip", "-l", ":8080", "-H", "X-Forwarded-For", "-f", "/db/GeoLite2-Country.mmdb", "-c", "/db/GeoLite2-City.mmdb"]