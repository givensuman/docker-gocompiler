FROM golang:1.22-alpine

RUN apk add --no-cache zig build-base bash && \
	rm -rf /var/cache/apk/*

WORKDIR /app

COPY builder.sh /bin/builder.sh
RUN chmod +x /bin/builder.sh

ENTRYPOINT ["/bin/builder.sh"]
