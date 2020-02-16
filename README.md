# LibClock - Tamriel Standard Time
[![Build Status](https://travis-ci.org/Tyxz/LibClock-Tamriel-Standard-Time.svg?branch=master)](https://travis-ci.org/Tyxz/LibClock-Tamriel-Standard-Time)
[![codecov](https://codecov.io/gh/Tyxz/LibClock-Tamriel-Standard-Time/branch/master/graph/badge.svg)](https://codecov.io/gh/Tyxz/LibClock-Tamriel-Standard-Time)
![GitHub issues](https://img.shields.io/github/issues/Tyxz/LibClock-Tamriel-Standard-Time)
![GitHub last commit](https://img.shields.io/github/last-commit/Tyxz/LibClock-Tamriel-Standard-Time)
[![Run on Repl.it](https://repl.it/badge/github/Tyxz/LibClock-Tamriel-Standard-Time)](https://repl.it/github/Tyxz/LibClock-Tamriel-Standard-Time)

|   |   |   |
|---|---|---|
| Version: | 1.0.0 | [![Documentation](https://img.shields.io/website?label=%7C&up_color=important&up_message=documentation&url=https%3A%2F%2Ftyxz.github.io%2FLibClock-Tamriel-Standard-Time%2F)](https://tyxz.github.io/LibClock-Tamriel-Standard-Time/) |  
| Build for game version: | 100030 | [![Download](https://img.shields.io/website?label=%7C&up_color=blue&up_message=download&url=http%3A%2F%2Fwww.esoui.com%2Fdownloads%2Finfo241-Clock-TamrielStandardTime.html)](https://www.esoui.com/downloads/info241-Clock-TamrielStandardTime.html) |

## How to use

1. Link it in your Addon.txt

   ```## DependsOn: LibClockTST```
2. Create an instance of the library in your addon

    ```local TST = LibClockTST:Instance()```
3. Subscribe to or get the needed data

    1. Subscribe
        ```
        local function myTimeAndDateUpdate(time date)
            d(time, date) 
        end
        TST:Register("MyAddonHandle", myTimeAndDateUpdate)
        ```

    2. Get

        ```local time, date = TST:GetTime(), TST:GetDate()```
        