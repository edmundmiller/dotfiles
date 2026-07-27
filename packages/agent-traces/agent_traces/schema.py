from pyiceberg.partitioning import PartitionField, PartitionSpec
from pyiceberg.schema import Schema
from pyiceberg.transforms import DayTransform, IdentityTransform
from pyiceberg.types import (
    BinaryType,
    IntegerType,
    LongType,
    NestedField,
    StringType,
    TimestamptzType,
)

ICEBERG_SCHEMA = Schema(
    NestedField(1, "source", StringType(), required=True),
    NestedField(2, "native_id", StringType(), required=True),
    NestedField(3, "version_hash", StringType(), required=True),
    NestedField(4, "observed_at", TimestamptzType(), required=True),
    NestedField(5, "native_modified_at", TimestamptzType(), required=True),
    NestedField(6, "started_at", TimestamptzType()),
    NestedField(7, "updated_at", TimestamptzType()),
    NestedField(8, "native_size", LongType(), required=True),
    NestedField(9, "native_format", StringType(), required=True),
    NestedField(10, "native_locator", StringType(), required=True),
    NestedField(11, "title", StringType()),
    NestedField(12, "cwd", StringType()),
    NestedField(13, "model", StringType()),
    NestedField(14, "normalization_status", StringType(), required=True),
    NestedField(15, "record_count", IntegerType(), required=True),
    NestedField(16, "diagnostics_json", StringType(), required=True),
    NestedField(17, "trajectory_json", StringType()),
    NestedField(18, "native_bytes", BinaryType(), required=True),
    identifier_field_ids=[1, 2, 3],
)

PARTITION_SPEC = PartitionSpec(
    PartitionField(1, 1000, IdentityTransform(), "source"),
    PartitionField(5, 1001, DayTransform(), "native_modified_day"),
)
