import 'package:hive/hive.dart';
import 'io_models.dart';

// Adapter for IntakeEntry
class IntakeEntryAdapter extends TypeAdapter<IntakeEntry> {
  @override
  final int typeId = 0;

  @override
  IntakeEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final fieldId = reader.readByte();
      fields[fieldId] = reader.read();
    }
    return IntakeEntry(
      id: fields[0] as String,
      userId: fields[1] as String,
      volume: fields[2] as double,
      fluidType: fields[3] as String,
      timestamp: fields[4] as DateTime,
      notes: fields[5] as String?,
      shift: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, IntakeEntry obj) {
    writer.writeByte(7);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.userId);
    writer.writeByte(2);
    writer.write(obj.volume);
    writer.writeByte(3);
    writer.write(obj.fluidType);
    writer.writeByte(4);
    writer.write(obj.timestamp);
    writer.writeByte(5);
    writer.write(obj.notes);
    writer.writeByte(6);
    writer.write(obj.shift);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntakeEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// Adapter for OutputEntry
class OutputEntryAdapter extends TypeAdapter<OutputEntry> {
  @override
  final int typeId = 1;

  @override
  OutputEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final fieldId = reader.readByte();
      fields[fieldId] = reader.read();
    }
    return OutputEntry(
      id: fields[0] as String,
      userId: fields[1] as String,
      volume: fields[2] as double,
      outputType: fields[3] as String,
      timestamp: fields[4] as DateTime,
      notes: fields[5] as String?,
      shift: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, OutputEntry obj) {
    writer.writeByte(7);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.userId);
    writer.writeByte(2);
    writer.write(obj.volume);
    writer.writeByte(3);
    writer.write(obj.outputType);
    writer.writeByte(4);
    writer.write(obj.timestamp);
    writer.writeByte(5);
    writer.write(obj.notes);
    writer.writeByte(6);
    writer.write(obj.shift);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutputEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// Adapter for ShiftData
class ShiftDataAdapter extends TypeAdapter<ShiftData> {
  @override
  final int typeId = 2;

  @override
  ShiftData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final fieldId = reader.readByte();
      fields[fieldId] = reader.read();
    }
    return ShiftData(
      totalIntake: fields[0] as double,
      totalOutput: fields[1] as double,
      intakeCount: fields[2] as int,
      outputCount: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ShiftData obj) {
    writer.writeByte(4);
    writer.writeByte(0);
    writer.write(obj.totalIntake);
    writer.writeByte(1);
    writer.write(obj.totalOutput);
    writer.writeByte(2);
    writer.write(obj.intakeCount);
    writer.writeByte(3);
    writer.write(obj.outputCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// Adapter for DailyFluidSummary
class DailyFluidSummaryAdapter extends TypeAdapter<DailyFluidSummary> {
  @override
  final int typeId = 3;

  @override
  DailyFluidSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final fieldId = reader.readByte();
      fields[fieldId] = reader.read();
    }
    return DailyFluidSummary(
      date: fields[0] as DateTime,
      totalIntake: fields[1] as double,
      totalOutput: fields[2] as double,
      intakeStatus: FluidStatus.values[fields[3] as int],
      outputStatus: FluidStatus.values[fields[4] as int],
      intakeEntries: (fields[5] as List?)?.cast<IntakeEntry>() ?? [],
      outputEntries: (fields[6] as List?)?.cast<OutputEntry>() ?? [],
      morningShift: fields[7] as ShiftData,
      afternoonShift: fields[8] as ShiftData,
      nightShift: fields[9] as ShiftData,
    );
  }

  @override
  void write(BinaryWriter writer, DailyFluidSummary obj) {
    writer.writeByte(10);
    writer.writeByte(0);
    writer.write(obj.date);
    writer.writeByte(1);
    writer.write(obj.totalIntake);
    writer.writeByte(2);
    writer.write(obj.totalOutput);
    writer.writeByte(3);
    writer.write(obj.intakeStatus.index);
    writer.writeByte(4);
    writer.write(obj.outputStatus.index);
    writer.writeByte(5);
    writer.write(obj.intakeEntries);
    writer.writeByte(6);
    writer.write(obj.outputEntries);
    writer.writeByte(7);
    writer.write(obj.morningShift);
    writer.writeByte(8);
    writer.write(obj.afternoonShift);
    writer.writeByte(9);
    writer.write(obj.nightShift);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyFluidSummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// Adapter for UserFluidRange
class UserFluidRangeAdapter extends TypeAdapter<UserFluidRange> {
  @override
  final int typeId = 4;

  @override
  UserFluidRange read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final fieldId = reader.readByte();
      fields[fieldId] = reader.read();
    }
    return UserFluidRange(
      userId: fields[0] as String,
      dailyIntakeTarget: fields[1] as double,
      dailyOutputTarget: fields[2] as double,
      shiftIntakeRangeMin: Map<String, double>.from(
        (fields[3] as Map).cast<String, double>(),
      ),
      shiftIntakeRangeMax: Map<String, double>.from(
        (fields[4] as Map).cast<String, double>(),
      ),
      shiftOutputRangeMin: Map<String, double>.from(
        (fields[5] as Map).cast<String, double>(),
      ),
      shiftOutputRangeMax: Map<String, double>.from(
        (fields[6] as Map).cast<String, double>(),
      ),
    );
  }

  @override
  void write(BinaryWriter writer, UserFluidRange obj) {
    writer.writeByte(7);
    writer.writeByte(0);
    writer.write(obj.userId);
    writer.writeByte(1);
    writer.write(obj.dailyIntakeTarget);
    writer.writeByte(2);
    writer.write(obj.dailyOutputTarget);
    writer.writeByte(3);
    writer.write(obj.shiftIntakeRangeMin);
    writer.writeByte(4);
    writer.write(obj.shiftIntakeRangeMax);
    writer.writeByte(5);
    writer.write(obj.shiftOutputRangeMin);
    writer.writeByte(6);
    writer.write(obj.shiftOutputRangeMax);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserFluidRangeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
