![](https://github.com/senselogic/PRISM/blob/master/LOGO/prism.png)

# Prism

Agile project planner and tracker.

## Features

- Reads backlog and sprint report files in **Markdown** format.
- Writes planning and tracking files in **TSV** format.

## Backlogs

```markdown
E-commerce Platform
- Implement user authentication API [John ~1 100% done] : 16h
- Set up payment gateway integration [John ~1 80% !1] : 8h
- Implement shopping cart functionality [John ~1 !1] : 16h
- Add order history tracking [John ~1 !1] : 8h
- Implement product recommendations [John ~1 !2] : 16h
- Add customer review system [John ~1 !2] : 8h
- Implement loyalty program [John ~1 !3] : 16h
- Add social commerce features [John ~1 !3] : 8h
- Implement marketplace integration [John ~2] : 16h
- Add subscription management [John ~2] : 8h
- Implement advanced payment methods [John ~2] : 16h
- Add customer analytics dashboard [John ~2] : 8h

Inventory Management System
- Create product catalog API [John ~1 100%] : 2h
- Backend :
  - Build order processing service [John ~1 100%] : 16h
  - Implement stock tracking endpoints [John ~1 100%] : 8h
- Frontend :
  - Design admin dashboard layout [John ~1 100%] : 1h
  - Add product search functionality [John ~1 100%] : 16h
- Build real-time inventory updates [John ~1 !1] : 8h
- Create reporting dashboard [John ~1 !1] : 16h
- Build automated reorder system [John ~1 !2] : 8h
- Create supplier management [John ~1 !2] : 16h
- Build demand forecasting [John ~1 !3] : 8h
- Create quality control system [John ~1 !3] : 16h
- Build vendor portal [John ~2] : 16h
- Create compliance tracking [John ~2] : 8h
- Implement inventory optimization [John ~2] : 16h
- Add barcode scanning system [John ~2] : 8h

Mobile Banking App
- Implement biometric login [Mike ~1 100%] : 16h
- Build transaction history API [Mike ~1 100%] : 8h
- Add money transfer functionality [Mike ~1 !1] : 16h
- Implement push notifications [Mike ~1 !1] : 8h
- Implement bill payment system [Mike ~1 !2] : 16h
- Add account aggregation [Mike ~1 !2] : 8h
- Implement investment portfolio [Mike ~1 !3] : 16h
- Add financial planning tools [Mike ~1 !3] : 8h
- Implement cryptocurrency trading [Mike ~2] : 16h
- Add insurance products [Mike ~2] : 8h
- Implement advanced security features [Mike ~2] : 16h
- Add mobile wallet integration [Mike ~2] : 8h

Financial Analytics Dashboard
- Create expense categorization [Mike ~1 100%] : 8h
- Implement budget tracking features [Mike ~1 100%] : 16h
- Build spending trend analysis [Mike ~1 !1] : 8h
- Add investment tracking [Mike ~1 !1] : 16h
- Create financial goal tracking [Mike ~1 !2] : 8h
- Build credit score monitoring [Mike ~1 !2] : 16h
- Create tax optimization [Mike ~1 !3] : 8h
- Build retirement planning [Mike ~1 !3] : 16h
- Create estate planning [Mike ~2] : 8h
- Build risk assessment [Mike ~2] : 16h
- Implement financial forecasting [Mike ~2] : 8h
- Add portfolio optimization [Mike ~2] : 16h
```

A backlog file contains project names (`E-commerce Platform`) followed by a hierarchical list of segments, groups, tasks and subtasks.

Each task includes a duration in minutes (`40m`), hours (`1h`, `1h30`), or days (`0.5d`).

Tasks can also include the following properties inside brackets :
- Developer name in PascalCase (`Mike`)
- Phase number (`~1`)
- Sprint number (`!1`)
- Completion percentage (`80%`)
- Status name in snake-case (`done`)

## Sprint reports

```markdown
# John

## 2025-07-28

### Done

E-commerce Platform
- Implement user authentication API [Monday, Tuesday]
- Set up payment gateway integration [Wednesday]

Inventory Management System
- Create product catalog API [Monday 1h30]
- Backend :
  - Build order processing service [Monday 2h, Tuesday]
  - Implement stock tracking endpoints [Wednesday]
- Frontend :
  - Design admin dashboard layout [Wednesday 50m]
  - Add product search functionality [Thursday, Friday]

### Next

E-commerce Platform
- Implement shopping cart functionality
- Add order history tracking

Inventory Management System
- Build real-time inventory updates
- Create reporting dashboard
```

A sprint report file starts with either :
- The developer name in PascalCase (`# John`), followed by the first sprint starting date (`## 2025-07-28`);
- The sprint starting date (`# 2025-07-28`), followed by the first developer name in PascalCase (`## John`).

Each sprint report contains two main sections :
- what has been completed during this sprint (`### Done`);
- what will be done in the next sprint (`### Next`).

Each section lists project names followed by a hierarchical list of segments, groups and tasks.

A task always ends with a list of working days in brackets, optionally including durations (`Monday 2h`, `Tuesday`, `Monday#2`).

If some tasks of a given workday don't have explicit durations, the remaining working time is evenly distributed among them.

## Installation

Install the [DMD 2 compiler](https://dlang.org/download.html) (using the MinGW setup option on Windows).

Build the executable with the following command line :

```bash
dmd -m64 prism.d
```

## Command line

```
prism {workday duration} {minimum duration factor} {medium duration factor} {maximum duration factor} INPUT_FOLDER/ OUTPUT_FOLDER/
```

### Example

```bash
prism 8h 1 1.5 2 INPUT_FOLDER/ OUTPUT_FOLDER/
```

## Limitations

- Backlog and sprint tasks are currently independent.

## Version

0.1

## Author

Eric Pelzer (ecstatic.coder@gmail.com).

## License

This project is licensed under the GNU General Public License version 3.

See the [LICENSE.md](LICENSE.md) file for details.
