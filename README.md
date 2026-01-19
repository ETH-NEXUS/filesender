# Filesender

This is a dockerized filesender for evaluation purposes. It uses [mocksaml.com](https://mocksaml.com/) as the IdP and [mailpit](https://hub.docker.com/r/axllent/mailpit)

more information can be found here: https://filsender.org

## Quick start

To setup the filesender locally please follow this instruction:

1. git pull git@github.com:dameyerdave/filesender.git
2. docker compose up -d
3. goto [https://localhost](https://localhost)
4. To check emails goto [http://localhost:8025](http://localhost:8025)

Or you just want to go for the pre-built docker image using this docker-compose.yml file:

```yaml
services:
  filesender:
    image: ethnexus/filesender
    ports:
      - 80:80
      - 443:443
    depends_on:
      - mailpit
    restart: unless-stopped
  mailpit:
    image: axllent/mailpit:v1.28
    hostname: mailpit
    restart: unless-stopped
    ports:
      - 8025:8025
```
