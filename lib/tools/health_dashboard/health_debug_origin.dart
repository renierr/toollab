/// Identity of the debug generator's records.
///
/// Android attributes every Health Connect record to the *writing package*, and
/// this app has exactly one - so generated data arrives under the same package
/// as the treadmill publisher's real workouts and would be labelled, filtered
/// and deleted as if it were them. It cannot be written under another package:
/// no app may claim a package it is not.
///
/// The client record id is therefore the only thing that separates the two, and
/// the collectors resolve a record's writer through
/// `HealthConnectMapper.packageOf` so a stamped record is filed under
/// [healthDebugPackage] instead.
const healthDebugClientIdPrefix = 'toollab:health-debug:';

/// Not a real package - nothing is installed under it, and Health Connect never
/// reports it. It exists so generated rows get their own `health_app` row, their
/// own source switch and priority, and a `deleteAppData` that by construction
/// cannot reach anything real.
const healthDebugPackage = 'de.renier.tool_lab.generated';
