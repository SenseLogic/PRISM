![](https://github.com/senselogic/PRISM/blob/master/LOGO/prism.png)

# Prism

Weekly summary compiler.

# Sample

```
=== John ===

# This week

E-commerce Platform
- Implemented user authentication API (Monday, Tuesday)
- Set up payment gateway integration (Wednesday)

Inventory Management System
- Created product catalog API (Monday 1h30)
- Backend :
  - Built order processing service (Monday 2h, Tuesday)
  - Implemented stock tracking endpoints (Wednesday)
- Frontend :
  - Designed admin dashboard layout (Wednesday 50m)
  - Added product search functionality (Thursday, Friday)

# Next week

E-commerce Platform
- Implement shopping cart functionality
- Add order history tracking

Inventory Management System
- Build real-time inventory updates
- Create reporting dashboard

=== Mike ===

# This week

Mobile Banking App
- Implemented biometric login (Monday, Tuesday)
- Built transaction history API (Wednesday)

Financial Analytics Dashboard
- Created expense categorization (Wednesday)
- Implemented budget tracking features (Thursday, Friday)

# Next week

Mobile Banking App
- Add money transfer functionality
- Implement push notifications

Financial Analytics Dashboard
- Build spending trend analysis
- Add investment tracking
```

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

## Version

0.1

## Author

Eric Pelzer (ecstatic.coder@gmail.com).

## License

This project is licensed under the GNU General Public License version 3.

See the [LICENSE.md](LICENSE.md) file for details.
