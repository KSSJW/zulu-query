# Zulu Query

An interactive Linux shell script to query the latest Azul Zulu OpenJDK builds and SHA-256 checksums via the official Metadata API.

## Dependencies

- `bash`
- `curl`
- `jq`

## Usage

1. `chmod +x zulu-query.sh`
2. `./zulu-query.sh`

## Options

- API Source
- CPU Architecture
- Java Major Version
- Package Type
- Archive Type

## Example Output

```
File Name: zulu27.30.201-ca-jdk27.0.1.1-linux_musl_x64.tar.gz
Zulu Version: 27.30.201
Java Version: 27.0.1.1
SHA-256: a96a6534f1936ee63308cda8f71134abc78bb0918312e5a67c5bb1da222a0956
Download URL: https://cdn.azul.com/zulu/bin/zulu27.30.201-ca-jdk27.0.1.1-linux_musl_x64.tar.gz
```

## License

MIT (MIT License)
