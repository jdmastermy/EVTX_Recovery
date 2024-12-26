# Windows Event Log Recovery

PowerShell script for recovering deleted Windows Event Log (.evtx) files using signature-based carving, with support for both traditional and optimized memory-mapped recovery methods.

## Features

- Fast recovery using memory-mapped file processing
- Optional parallel processing support
- Traditional signature-based recovery method available
- Progress tracking and validation of recovered logs
- Configurable buffer sizes for different system capabilities

## Recovery Methods

### Optimized Method (Default)
The optimized method uses memory-mapped files for faster processing:
- Maps the drive directly into memory space
- Reduces I/O overhead compared to traditional file reading
- Supports parallel processing for multi-core systems
- Better performance on large drives
- More efficient memory usage
- Recommended for modern systems with sufficient RAM

### Traditional Method
The traditional method uses standard file I/O:
- Sequential signature scanning
- Lower memory usage
- More compatible with older systems
- Better for small, targeted recoveries
- Useful when memory-mapped approach isn't viable
- More reliable on systems with limited resources

Performance comparison on a typical system (1TB drive):

| Method     | Processing Speed | CPU Usage | Memory Usage |
|------------|-----------------|-----------|--------------|
| Traditional| 50-100 MB/s     | Single Core| ~200MB      |
| Optimized  | 200-400 MB/s    | Multi-Core | ~400MB      |

## Requirements

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or later
- Administrative privileges
- Minimum 8GB RAM for optimized method (16GB recommended)
- 4GB RAM minimum for traditional method

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

## Method Selection Guide

Choose the optimized method when:
- Running on a modern system with 8GB+ RAM
- Processing large drives (>500GB)
- Fast recovery is prioritized
- System has multiple CPU cores
- Memory-mapped files are supported

Choose the traditional method when:
- Running on systems with limited RAM (<8GB)
- Processing small drives or specific areas
- System stability is prioritized over speed
- Troubleshooting recovery issues
- Memory-mapped files cause issues

## Performance Tips

- Use optimized method (default) for better performance
- Enable parallel processing (-UseParallel) on multi-core systems
- Adjust buffer size based on available RAM:
  - 32MB-64MB for systems with 8GB RAM
  - 64MB-128MB for systems with 16GB+ RAM
  - 16MB-32MB for traditional method
- Use SSD for both source and destination drives when possible

## Recovery Process

1. The script first validates administrative privileges
2. Scans the drive for EVTX file signatures (magic numbers)
3. Validates potential event log headers
4. Extracts validated logs to the specified output directory
5. Provides progress updates during scanning
6. Reports the number of logs recovered

## Common Issues

- **Access Denied**: Run PowerShell as Administrator
- **Memory Issues**: 
  - Reduce buffer size
  - Switch to traditional method
  - Close unnecessary applications
- **Slow Performance**: 
  - Enable parallel processing
  - Adjust buffer size
  - Check drive health
- **No Logs Found**: 
  - Try traditional method
  - Verify drive accessibility
  - Check for drive corruption

## License

MIT License - feel free to use and modify as needed.

## Contributing

Feel free to submit issues and pull requests.

## Technical Details

The script uses the following techniques:
- EVTX signature detection (magic numbers: ElfFile)
- Memory-mapped file API for optimized access
- PowerShell jobs for parallel processing
- Standard .NET file I/O for traditional method
- Header structure validation
- Chunk-based processing for efficient memory usage