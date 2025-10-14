![](https://github.com/senselogic/PRISM/blob/master/LOGO/prism.png)

# Prism

Weekly summary compiler.

## Installation

Install the [DMD 2 compiler](https://dlang.org/download.html) (using the MinGW setup option on Windows).

Build the executable with the following command line :

```bash
dmd -m64 prism.d
```

## Command line

```
prism <workday duration> <input folder path> <output folder path>
```

### Example

```bash
prism 8h INPUT_FOLDER/ OUTPUT_FOLDER/
```

Compiles the weekly summaries into TSV data using 8 hours as workday duration.

## Version

0.1

## Author

Eric Pelzer (ecstatic.coder@gmail.com).

## License

This project is licensed under the GNU General Public License version 3.

See the [LICENSE.md](LICENSE.md) file for details.
