# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Most inportant roles

英語で考えて日本語で回答・報告してください。


## MQL5 Development Environment

This is a MetaTrader 5 (MT5) MQL5 development directory containing Expert Advisors, Indicators, Scripts, and Libraries.

### Key Commands

**Compilation**: MQL5 files are compiled within MetaTrader 5's MetaEditor IDE
- Source files: `.mq5` (code), `.mqh` (headers)
- Compiled files: `.ex5` (executables)
- Project files: `.mqproj` (JSON format, UTF-16 encoded)

**Testing**:
- Unit tests: Located in `/Scripts/UnitTests/`
- Strategy Tester: Use `.set` files for EA optimization parameters
- Run scripts directly in MT5 terminal for one-time execution

### Architecture Overview

```
/MQL5/
├── Experts/          # Trading robots (EAs)
│   ├── Advisors/     # Standard EAs (MACD, Moving Average)
│   └── Free Robots/  # Pattern recognition EAs
├── Indicators/       # Technical analysis tools
│   ├── Examples/     # Standard indicators (ADX, ATR, RSI)
│   └── Free Indicators/ # Channel indicators
├── Scripts/          # Utility scripts and tests
├── Include/          # Shared libraries and headers
│   ├── Trade/        # Trading operations classes
│   ├── Math/         # Mathematical functions
│   └── Controls/     # UI components
└── Profiles/         # User settings and templates
```

### Core MQL5 Structure

**Expert Advisors**:
- Entry points: `OnInit()`, `OnTick()`, `OnDeinit()`
- Include: `<Trade\Trade.mqh>`, `<Trade\SymbolInfo.mqh>`
- Use magic numbers for order identification

**Indicators**:
- Entry points: `OnInit()`, `OnCalculate()`
- Buffer management with `SetIndexBuffer()`
- Use `#property indicator_*` directives

**Scripts**:
- Entry point: `OnStart()`
- One-time execution utilities

### Important Libraries

- `/Include/Trade/`: Trading operations (CTrade, CPositionInfo, CSymbolInfo)
- `/Include/Math/`: Statistical and mathematical functions
- `/Include/Canvas/`: Custom graphics and visualization
- `/Include/Generic/`: Data structures (HashMap, ArrayList)
- `/Include/Alglib/`: Advanced mathematical algorithms

### Project Configuration

`.mqproj` files control:
- `platform`: "mt5"
- `program_type`: "expert"/"script"/"indicator"
- `optimize`: "1" for optimization
- `fpzerocheck`: "1" for floating-point checking
- File compilation dependencies

### Testing Approach

1. Unit tests in `/Scripts/UnitTests/` test mathematical libraries
2. Strategy Tester for EA backtesting with `.set` parameter files
3. Visual testing mode available for debugging
4. Math calculation mode for non-trading EA testing

### Notable Features

- OpenCL support for GPU computing (see `/Scripts/Examples/OpenCL/`)
- DirectX integration for 3D visualization
- Extensive candlestick pattern recognition in Free Robots
- Risk management tools (e.g., RiskPanelChartJP)
- Multi-language support capabilities