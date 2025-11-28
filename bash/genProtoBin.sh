#!/bin/bash

# https://github.com/protocolbuffers/protobuf?tab=readme-ov-file#protobuf-compiler-installation

# Generate Binary Protobuf message Body for BulkDetails Request
genBulkDetailsProtoBin() {
  # Create protobuf SCHEMA file (defines blueprint/STRUCTURE)
  cat > bulkDetails.proto << 'EOF'
syntax = "proto3";

message BulkRequest {  // ← TYPE define
  repeated string packages = 1;  // ← Field number 1
}
EOF
  
  # Create Input Data File that matches schema
  {
    for pkgname in "${pkgnames[@]}"; do
      echo "packages: \"$pkgname\""
    done
  } > bulkDetails.txt
  # protoc (Protocol Buffers Compiler) validates data against schema & generate (bin) binary protobuf file
  protoc --proto_path=. --encode=BulkRequest bulkDetails.proto < bulkDetails.txt > bulkDetails.bin && rm -f bulkDetails.txt bulkDetails.proto
}

# Generate Binary Protobuf Body for AcquireRequest
genAcquireProtoBin() {
  # Create proto file with optional fields
  cat > acquire.proto << 'EOF'
syntax = "proto3";

message Payload {
  int32 field2 = 2;
  int32 field3 = 3;
  string field4 = 4;
}

message Package {
  Payload field1 = 1;
  int32 field2 = 2;
}

message Version {
  int32 field1 = 1;
  optional int32 field3 = 3;  // ← optional to preserve zero
}

message Message30 {
  int32 field1 = 1;
  optional int32 field2 = 2;  // ← optional to preserve zero
}

message RootMessage {
  Package field1 = 1;
  Version field2 = 2;
  string field13 = 13;
  optional int32 field15 = 15;  // ← optional to preserve zero
  int32 field19 = 19;
  int32 field25 = 25;
  Message30 field30 = 30;
}
EOF
  
  nonce=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)  # Generate random nonce

  # Create text format input
  {
  cat << EOF
field1 {
  field1 {
    field2: 1
    field3: 3
    field4: "$packageName"
  }
  field2: 1
}
field2 {
  field1: $versionCode
  field3: 0
}
field13: "$nonce"
field15: 0
field19: $offerType
field25: 2
field30 {
  field1: 2
  field2: 0
}
EOF
  } | protoc --proto_path=. --encode=RootMessage acquire.proto > acquire.bin && rm -f acquire.proto
}
###################################################################################################