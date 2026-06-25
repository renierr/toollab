import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/unit_model.dart';

/// The full catalog of conversion categories and their units.
///
/// Linear units use [UnitDef.factor] (`value * factor = base`). Temperature and
/// fuel economy use explicit [UnitDef.toBase] / [UnitDef.fromBase] closures.
class UnitCatalog {
  UnitCatalog._();

  static const double _radPerDeg = 180.0 / math.pi; // degrees per radian

  static final List<UnitCategory> categories = [
    // ---------------------------------------------------------------- Length
    UnitCategory(
      id: 'length',
      icon: Icons.straighten,
      name: (l) => l.ucCatLength,
      units: [
        UnitDef(id: 'meter', symbol: 'm', factor: 1, name: (l) => l.ucuMeter),
        UnitDef(
          id: 'kilometer',
          symbol: 'km',
          factor: 1000,
          name: (l) => l.ucuKilometer,
        ),
        UnitDef(
          id: 'centimeter',
          symbol: 'cm',
          factor: 0.01,
          name: (l) => l.ucuCentimeter,
        ),
        UnitDef(
          id: 'millimeter',
          symbol: 'mm',
          factor: 0.001,
          name: (l) => l.ucuMillimeter,
        ),
        UnitDef(
          id: 'mile',
          symbol: 'mi',
          factor: 1609.344,
          name: (l) => l.ucuMile,
        ),
        UnitDef(
          id: 'yard',
          symbol: 'yd',
          factor: 0.9144,
          name: (l) => l.ucuYard,
        ),
        UnitDef(
          id: 'foot',
          symbol: 'ft',
          factor: 0.3048,
          name: (l) => l.ucuFoot,
        ),
        UnitDef(
          id: 'inch',
          symbol: 'in',
          factor: 0.0254,
          name: (l) => l.ucuInch,
        ),
      ],
    ),
    // ------------------------------------------------------------------ Mass
    UnitCategory(
      id: 'mass',
      icon: Icons.scale_outlined,
      name: (l) => l.ucCatMass,
      units: [
        UnitDef(
          id: 'kilogram',
          symbol: 'kg',
          factor: 1,
          name: (l) => l.ucuKilogram,
        ),
        UnitDef(id: 'gram', symbol: 'g', factor: 0.001, name: (l) => l.ucuGram),
        UnitDef(
          id: 'milligram',
          symbol: 'mg',
          factor: 1e-6,
          name: (l) => l.ucuMilligram,
        ),
        UnitDef(
          id: 'metric_ton',
          symbol: 't',
          factor: 1000,
          name: (l) => l.ucuMetricTon,
        ),
        UnitDef(
          id: 'pound',
          symbol: 'lb',
          factor: 0.45359237,
          name: (l) => l.ucuPound,
        ),
        UnitDef(
          id: 'ounce',
          symbol: 'oz',
          factor: 0.028349523125,
          name: (l) => l.ucuOunce,
        ),
        UnitDef(
          id: 'stone',
          symbol: 'st',
          factor: 6.35029318,
          name: (l) => l.ucuStone,
        ),
        UnitDef(
          id: 'us_ton',
          symbol: 'ton',
          factor: 907.18474,
          name: (l) => l.ucuUsTon,
        ),
      ],
    ),
    // ----------------------------------------------------------- Temperature
    UnitCategory(
      id: 'temperature',
      icon: Icons.thermostat,
      name: (l) => l.ucCatTemperature,
      units: [
        UnitDef(id: 'celsius', symbol: '°C', name: (l) => l.ucuCelsius),
        UnitDef(
          id: 'fahrenheit',
          symbol: '°F',
          name: (l) => l.ucuFahrenheit,
          toBase: (v) => (v - 32) * 5 / 9,
          fromBase: (c) => c * 9 / 5 + 32,
        ),
        UnitDef(
          id: 'kelvin',
          symbol: 'K',
          name: (l) => l.ucuKelvin,
          toBase: (v) => v - 273.15,
          fromBase: (c) => c + 273.15,
        ),
        UnitDef(
          id: 'rankine',
          symbol: '°R',
          name: (l) => l.ucuRankine,
          toBase: (v) => (v - 491.67) * 5 / 9,
          fromBase: (c) => (c + 273.15) * 9 / 5,
        ),
      ],
    ),
    // ------------------------------------------------------------------ Area
    UnitCategory(
      id: 'area',
      icon: Icons.crop_square,
      name: (l) => l.ucCatArea,
      units: [
        UnitDef(
          id: 'square_meter',
          symbol: 'm²',
          factor: 1,
          name: (l) => l.ucuSquareMeter,
        ),
        UnitDef(
          id: 'square_kilometer',
          symbol: 'km²',
          factor: 1e6,
          name: (l) => l.ucuSquareKilometer,
        ),
        UnitDef(
          id: 'square_centimeter',
          symbol: 'cm²',
          factor: 1e-4,
          name: (l) => l.ucuSquareCentimeter,
        ),
        UnitDef(
          id: 'hectare',
          symbol: 'ha',
          factor: 10000,
          name: (l) => l.ucuHectare,
        ),
        UnitDef(
          id: 'square_mile',
          symbol: 'mi²',
          factor: 2589988.110336,
          name: (l) => l.ucuSquareMile,
        ),
        UnitDef(
          id: 'acre',
          symbol: 'ac',
          factor: 4046.8564224,
          name: (l) => l.ucuAcre,
        ),
        UnitDef(
          id: 'square_foot',
          symbol: 'ft²',
          factor: 0.09290304,
          name: (l) => l.ucuSquareFoot,
        ),
      ],
    ),
    // ---------------------------------------------------------------- Volume
    UnitCategory(
      id: 'volume',
      icon: Icons.local_drink_outlined,
      name: (l) => l.ucCatVolume,
      units: [
        UnitDef(id: 'liter', symbol: 'L', factor: 1, name: (l) => l.ucuLiter),
        UnitDef(
          id: 'milliliter',
          symbol: 'mL',
          factor: 0.001,
          name: (l) => l.ucuMilliliter,
        ),
        UnitDef(
          id: 'cubic_meter',
          symbol: 'm³',
          factor: 1000,
          name: (l) => l.ucuCubicMeter,
        ),
        UnitDef(
          id: 'gallon_us',
          symbol: 'gal',
          factor: 3.785411784,
          name: (l) => l.ucuGallonUs,
        ),
        UnitDef(
          id: 'quart_us',
          symbol: 'qt',
          factor: 0.946352946,
          name: (l) => l.ucuQuartUs,
        ),
        UnitDef(
          id: 'pint_us',
          symbol: 'pt',
          factor: 0.473176473,
          name: (l) => l.ucuPintUs,
        ),
        UnitDef(
          id: 'cup_us',
          symbol: 'cup',
          factor: 0.2365882365,
          name: (l) => l.ucuCupUs,
        ),
        UnitDef(
          id: 'fluid_ounce_us',
          symbol: 'fl oz',
          factor: 0.029573529563,
          name: (l) => l.ucuFluidOunceUs,
        ),
      ],
    ),
    // ----------------------------------------------------------------- Speed
    UnitCategory(
      id: 'speed',
      icon: Icons.speed,
      name: (l) => l.ucCatSpeed,
      units: [
        UnitDef(
          id: 'meter_per_second',
          symbol: 'm/s',
          factor: 1,
          name: (l) => l.ucuMeterPerSecond,
        ),
        UnitDef(
          id: 'kilometer_per_hour',
          symbol: 'km/h',
          factor: 1 / 3.6,
          name: (l) => l.ucuKilometerPerHour,
        ),
        UnitDef(
          id: 'mile_per_hour',
          symbol: 'mph',
          factor: 0.44704,
          name: (l) => l.ucuMilePerHour,
        ),
        UnitDef(
          id: 'foot_per_second',
          symbol: 'ft/s',
          factor: 0.3048,
          name: (l) => l.ucuFootPerSecond,
        ),
        UnitDef(
          id: 'knot',
          symbol: 'kn',
          factor: 0.514444,
          name: (l) => l.ucuKnot,
        ),
        UnitDef(
          id: 'mach',
          symbol: 'Mach',
          factor: 343.0,
          name: (l) => l.ucuMach,
        ),
      ],
    ),
    // ------------------------------------------------------------------ Time
    UnitCategory(
      id: 'time',
      icon: Icons.schedule,
      name: (l) => l.ucCatTime,
      units: [
        UnitDef(id: 'second', symbol: 's', factor: 1, name: (l) => l.ucuSecond),
        UnitDef(
          id: 'millisecond',
          symbol: 'ms',
          factor: 0.001,
          name: (l) => l.ucuMillisecond,
        ),
        UnitDef(
          id: 'minute',
          symbol: 'min',
          factor: 60,
          name: (l) => l.ucuMinute,
        ),
        UnitDef(id: 'hour', symbol: 'h', factor: 3600, name: (l) => l.ucuHour),
        UnitDef(id: 'day', symbol: 'd', factor: 86400, name: (l) => l.ucuDay),
        UnitDef(
          id: 'week',
          symbol: 'wk',
          factor: 604800,
          name: (l) => l.ucuWeek,
        ),
        UnitDef(
          id: 'month',
          symbol: 'mo',
          factor: 2629746,
          name: (l) => l.ucuMonth,
        ),
        UnitDef(
          id: 'year',
          symbol: 'yr',
          factor: 31556952,
          name: (l) => l.ucuYear,
        ),
      ],
    ),
    // --------------------------------------------------------- Digital data
    UnitCategory(
      id: 'data',
      icon: Icons.sd_storage_outlined,
      name: (l) => l.ucCatData,
      units: [
        UnitDef(id: 'byte', symbol: 'B', factor: 1, name: (l) => l.ucuByte),
        UnitDef(
          id: 'kilobyte',
          symbol: 'KB',
          factor: 1000,
          name: (l) => l.ucuKilobyte,
        ),
        UnitDef(
          id: 'megabyte',
          symbol: 'MB',
          factor: 1e6,
          name: (l) => l.ucuMegabyte,
        ),
        UnitDef(
          id: 'gigabyte',
          symbol: 'GB',
          factor: 1e9,
          name: (l) => l.ucuGigabyte,
        ),
        UnitDef(
          id: 'terabyte',
          symbol: 'TB',
          factor: 1e12,
          name: (l) => l.ucuTerabyte,
        ),
        UnitDef(
          id: 'kibibyte',
          symbol: 'KiB',
          factor: 1024,
          name: (l) => l.ucuKibibyte,
        ),
        UnitDef(
          id: 'mebibyte',
          symbol: 'MiB',
          factor: 1048576,
          name: (l) => l.ucuMebibyte,
        ),
        UnitDef(
          id: 'gibibyte',
          symbol: 'GiB',
          factor: 1073741824,
          name: (l) => l.ucuGibibyte,
        ),
        UnitDef(id: 'bit', symbol: 'bit', factor: 0.125, name: (l) => l.ucuBit),
        UnitDef(
          id: 'megabit',
          symbol: 'Mbit',
          factor: 125000,
          name: (l) => l.ucuMegabit,
        ),
      ],
    ),
    // -------------------------------------------------------------- Pressure
    UnitCategory(
      id: 'pressure',
      icon: Icons.compress,
      name: (l) => l.ucCatPressure,
      units: [
        UnitDef(
          id: 'pascal',
          symbol: 'Pa',
          factor: 1,
          name: (l) => l.ucuPascal,
        ),
        UnitDef(
          id: 'kilopascal',
          symbol: 'kPa',
          factor: 1000,
          name: (l) => l.ucuKilopascal,
        ),
        UnitDef(
          id: 'bar',
          symbol: 'bar',
          factor: 100000,
          name: (l) => l.ucuBar,
        ),
        UnitDef(
          id: 'millibar',
          symbol: 'mbar',
          factor: 100,
          name: (l) => l.ucuMillibar,
        ),
        UnitDef(
          id: 'atmosphere',
          symbol: 'atm',
          factor: 101325,
          name: (l) => l.ucuAtmosphere,
        ),
        UnitDef(
          id: 'torr',
          symbol: 'Torr',
          factor: 133.3223684,
          name: (l) => l.ucuTorr,
        ),
        UnitDef(
          id: 'psi',
          symbol: 'psi',
          factor: 6894.757293168,
          name: (l) => l.ucuPsi,
        ),
        UnitDef(
          id: 'mmhg',
          symbol: 'mmHg',
          factor: 133.322387415,
          name: (l) => l.ucuMmhg,
        ),
      ],
    ),
    // ---------------------------------------------------------------- Energy
    UnitCategory(
      id: 'energy',
      icon: Icons.bolt_outlined,
      name: (l) => l.ucCatEnergy,
      units: [
        UnitDef(id: 'joule', symbol: 'J', factor: 1, name: (l) => l.ucuJoule),
        UnitDef(
          id: 'kilojoule',
          symbol: 'kJ',
          factor: 1000,
          name: (l) => l.ucuKilojoule,
        ),
        UnitDef(
          id: 'calorie',
          symbol: 'cal',
          factor: 4.184,
          name: (l) => l.ucuCalorie,
        ),
        UnitDef(
          id: 'kilocalorie',
          symbol: 'kcal',
          factor: 4184,
          name: (l) => l.ucuKilocalorie,
        ),
        UnitDef(
          id: 'watt_hour',
          symbol: 'Wh',
          factor: 3600,
          name: (l) => l.ucuWattHour,
        ),
        UnitDef(
          id: 'kilowatt_hour',
          symbol: 'kWh',
          factor: 3600000,
          name: (l) => l.ucuKilowattHour,
        ),
        UnitDef(
          id: 'electronvolt',
          symbol: 'eV',
          factor: 1.602176634e-19,
          name: (l) => l.ucuElectronvolt,
        ),
        UnitDef(
          id: 'btu',
          symbol: 'BTU',
          factor: 1055.05585262,
          name: (l) => l.ucuBtu,
        ),
      ],
    ),
    // ----------------------------------------------------------------- Power
    UnitCategory(
      id: 'power',
      icon: Icons.flash_on_outlined,
      name: (l) => l.ucCatPower,
      units: [
        UnitDef(id: 'watt', symbol: 'W', factor: 1, name: (l) => l.ucuWatt),
        UnitDef(
          id: 'kilowatt',
          symbol: 'kW',
          factor: 1000,
          name: (l) => l.ucuKilowatt,
        ),
        UnitDef(
          id: 'megawatt',
          symbol: 'MW',
          factor: 1e6,
          name: (l) => l.ucuMegawatt,
        ),
        UnitDef(
          id: 'milliwatt',
          symbol: 'mW',
          factor: 0.001,
          name: (l) => l.ucuMilliwatt,
        ),
        UnitDef(
          id: 'horsepower',
          symbol: 'hp',
          factor: 745.69987158,
          name: (l) => l.ucuHorsepower,
        ),
        UnitDef(
          id: 'metric_horsepower',
          symbol: 'PS',
          factor: 735.49875,
          name: (l) => l.ucuMetricHorsepower,
        ),
      ],
    ),
    // ----------------------------------------------------------------- Angle
    UnitCategory(
      id: 'angle',
      icon: Icons.architecture,
      name: (l) => l.ucCatAngle,
      units: [
        UnitDef(id: 'degree', symbol: '°', factor: 1, name: (l) => l.ucuDegree),
        UnitDef(
          id: 'radian',
          symbol: 'rad',
          factor: _radPerDeg,
          name: (l) => l.ucuRadian,
        ),
        UnitDef(
          id: 'gradian',
          symbol: 'gon',
          factor: 0.9,
          name: (l) => l.ucuGradian,
        ),
        UnitDef(
          id: 'arcminute',
          symbol: '′',
          factor: 1 / 60,
          name: (l) => l.ucuArcminute,
        ),
        UnitDef(
          id: 'arcsecond',
          symbol: '″',
          factor: 1 / 3600,
          name: (l) => l.ucuArcsecond,
        ),
        UnitDef(
          id: 'turn',
          symbol: 'turn',
          factor: 360,
          name: (l) => l.ucuTurn,
        ),
      ],
    ),
    // ------------------------------------------------------------- Frequency
    UnitCategory(
      id: 'frequency',
      icon: Icons.graphic_eq,
      name: (l) => l.ucCatFrequency,
      units: [
        UnitDef(id: 'hertz', symbol: 'Hz', factor: 1, name: (l) => l.ucuHertz),
        UnitDef(
          id: 'kilohertz',
          symbol: 'kHz',
          factor: 1000,
          name: (l) => l.ucuKilohertz,
        ),
        UnitDef(
          id: 'megahertz',
          symbol: 'MHz',
          factor: 1e6,
          name: (l) => l.ucuMegahertz,
        ),
        UnitDef(
          id: 'gigahertz',
          symbol: 'GHz',
          factor: 1e9,
          name: (l) => l.ucuGigahertz,
        ),
        UnitDef(
          id: 'rpm',
          symbol: 'rpm',
          factor: 1 / 60,
          name: (l) => l.ucuRpm,
        ),
      ],
    ),
    // ------------------------------------------------------------- Data rate
    UnitCategory(
      id: 'data_rate',
      icon: Icons.network_check,
      name: (l) => l.ucCatDataRate,
      units: [
        UnitDef(
          id: 'bit_per_second',
          symbol: 'bit/s',
          factor: 1,
          name: (l) => l.ucuBitPerSecond,
        ),
        UnitDef(
          id: 'kilobit_per_second',
          symbol: 'kbit/s',
          factor: 1000,
          name: (l) => l.ucuKilobitPerSecond,
        ),
        UnitDef(
          id: 'megabit_per_second',
          symbol: 'Mbit/s',
          factor: 1e6,
          name: (l) => l.ucuMegabitPerSecond,
        ),
        UnitDef(
          id: 'gigabit_per_second',
          symbol: 'Gbit/s',
          factor: 1e9,
          name: (l) => l.ucuGigabitPerSecond,
        ),
        UnitDef(
          id: 'byte_per_second',
          symbol: 'B/s',
          factor: 8,
          name: (l) => l.ucuBytePerSecond,
        ),
        UnitDef(
          id: 'kilobyte_per_second',
          symbol: 'KB/s',
          factor: 8000,
          name: (l) => l.ucuKilobytePerSecond,
        ),
        UnitDef(
          id: 'megabyte_per_second',
          symbol: 'MB/s',
          factor: 8e6,
          name: (l) => l.ucuMegabytePerSecond,
        ),
        UnitDef(
          id: 'gigabyte_per_second',
          symbol: 'GB/s',
          factor: 8e9,
          name: (l) => l.ucuGigabytePerSecond,
        ),
      ],
    ),
    // ----------------------------------------------------------- Fuel economy
    UnitCategory(
      id: 'fuel',
      icon: Icons.local_gas_station_outlined,
      name: (l) => l.ucCatFuel,
      units: [
        // Base unit: kilometers per liter (km/L).
        UnitDef(
          id: 'km_per_liter',
          symbol: 'km/L',
          factor: 1,
          name: (l) => l.ucuKmPerLiter,
        ),
        UnitDef(
          id: 'liter_per_100km',
          symbol: 'L/100km',
          name: (l) => l.ucuLiterPer100km,
          toBase: (v) => v == 0 ? double.infinity : 100 / v,
          fromBase: (b) => b == 0 ? double.infinity : 100 / b,
        ),
        UnitDef(
          id: 'mpg_us',
          symbol: 'mpg',
          factor: 0.425143707,
          name: (l) => l.ucuMpgUs,
        ),
        UnitDef(
          id: 'mpg_uk',
          symbol: 'mpg',
          factor: 0.354006186,
          name: (l) => l.ucuMpgUk,
        ),
      ],
    ),
  ];

  static UnitCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}
