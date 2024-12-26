# Windows Event Log Recovery

PowerShell script for recovering deleted Windows Event Log (.evtx) files using signature-based carving, with support for both traditional and optimized memory-mapped recovery methods.

## Features

- Fast recovery using memory-mapped file processing
- Optional parallel processing support
- Traditional signature-based recovery method available
- Progress tracking and validation of recovered logs
- Configurable buffer sizes for different system capabilities

## Requirements

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or later
- Administrative privileges

## Usage

1. Clone or download the script
2. Run as Administrator with your desired options:

```powershell
# Using optimized method (recommended)
.\EventLogRecovery.ps1 -DriveLetter "C:" -OutputPath "C:\Recovery" -UseParallel

# Using traditional method
.\EventLogRecovery.ps1 -DriveLetter "C:" -OutputPath "C:\Recovery" -UseTraditional

# With custom buffer size
.\EventLogRecovery.ps1 -DriveLetter "C:" -OutputPath "C:\Recovery" -BufferSize 128MB
```

### Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| DriveLetter | Drive to scan | Yes | - |
| OutputPath | Where to save recovered logs | Yes | - |
| UseTraditional | Use traditional scanning method | No | False |
| UseParallel | Enable parallel processing | No | False |
| BufferSize | Buffer size for reading | No | 64MB |

## Performance Tips

- Use optimized method (default) for better performance
- Enable parallel processing (-UseParallel) on multi-core systems
- Adjust buffer size based on available RAM:
  - 32MB-64MB for systems with 8GB RAM
  - 64MB-128MB for systems with 16GB+ RAM
- Use SSD for both source and destination drives when possible

## Common Issues

- **Access Denied**: Run PowerShell as Administrator
- **Memory Issues**: Reduce buffer size
- **Slow Performance**: Enable parallel processing or adjust buffer size
- **No Logs Found**: Try traditional method instead

## License

MIT License - feel free to use and modify as needed.

## Contributing

Feel free to submit issues and pull requests.