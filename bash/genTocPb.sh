#!/bin/bash

# Copyright (C) 2025, Arghyadeep Mondal <github.com/arghya339>

genTocPb() {

  if [ "$cpuAbi" == "arm64-v8a" ]; then arch="arm64_v8a"; elif [ "$cpuAbi" == "armeabi-v7a" ]; then arch="armeabi_v7a"; else arch="$cpuAbi"; fi
  language_value=$(cut -d'_' -f1 <<< $Locales)

  # proto definition
  cat > toc.proto << 'EOF'
syntax = "proto2";
package android.bundle;
message Toc {
  message BundleConfig {
    optional int32 dummy = 1;
  }
  repeated BundleConfig bundle_config = 1;
  message Module {
    optional string name = 1;
    repeated Split splits = 2;
    optional string unknown_5 = 5;
    optional int32 unknown_6 = 6;
    optional int32 unknown_7 = 7;
  }
  repeated Module modules = 2;
  optional string package_name = 4;
  optional string split_name = 5;
}
message Split {
  optional Targeting targeting = 1;
  optional string apk_path = 2;
  optional SplitConfig config = 3;
  optional string unknown_10 = 10;
}
message SplitConfig {
  optional string split_id = 1;
  optional int32 master_flag = 2;
}
message Targeting {
  message Abi {
    optional int32 value = 1;
  }
  message AbiTargeting {
    repeated Abi abi = 1;
    repeated Abi variant = 2;
  }
  message Language {
    optional string value = 1;
  }
  message Density {
    optional int32 value = 1;
  }
  message DensityTargeting {
    repeated Density density = 1;
    repeated Density alternatives = 2;
  }
  message SdkVersion {
    optional int32 min = 1;
  }
  message SdkTargeting {
    optional SdkVersion sdk_version = 1;
  }
  optional AbiTargeting abi = 1;
  optional Language language = 3;
  optional DensityTargeting density = 4;
  optional SdkTargeting sdk = 5;
}
EOF

  # proto base modules text
  cat > toc.txt << EOF
package_name: "$packageName"
bundle_config {
  dummy: 1
}
modules {
  name: "base"
  unknown_5: ""
  unknown_6: 1
  unknown_7: 1

  splits {
    apk_path: "splits/base-master.apk"
    config { master_flag: 1 }
    targeting {
      sdk {
        sdk_version { min: $minSdkVersion }
      }
    }
    unknown_10: ""
  }
EOF

  # proto density modules text
  density_toc() {
    cat >> toc.txt << EOF
  splits {
    apk_path: "splits/base-$dpi_value.apk"
    config { split_id: "$density_id" }
    targeting {
      density {
        density { value: $density_value }
        alternatives { value: ${density_alt[0]} }
        alternatives { value: ${density_alt[1]} }
        alternatives { value: ${density_alt[2]} }
        alternatives { value: ${density_alt[3]} }
        alternatives { value: ${density_alt[4]} }
        alternatives { value: ${density_alt[5]} }
      }
      sdk {
        sdk_version { min: $minSdkVersion }
      }
    }
    unknown_10: ""
  }
EOF
  }

  # proto abi modules text
  abi_toc() {
    cat >> toc.txt << EOF
  splits {
    apk_path: "splits/base-$arch_value.apk"
    config { split_id: "$abi_id" }
    targeting {
      abi {
        abi { value: $abi_value }
        variant { value: ${abi_variant[0]} }
        variant { value: ${abi_variant[1]} }
        variant { value: ${abi_variant[2]} }
      }
      sdk {
        sdk_version { min: $minSdkVersion }
      }
    }
    unknown_10: ""
  }
EOF
  }

  # proto language modules text
  language_toc() {
    cat >> toc.txt << EOF
  splits {
    apk_path: "splits/base-$language_value.apk"
    config { split_id: "$language_id" }
    targeting {
      language { value: "$language_value" }
      sdk {
        sdk_version { min: $minSdkVersion }
      }
    }
    unknown_10: ""
  }
EOF
  }

  for file in ${Files[@]}; do
    case $file in
      config.*dpi)
        dpi_value=$(cut -d'.' -f2 <<< $file)
        density_id=$file
        case $file in
          config.ldpi) density_value=2; density_alt=(3 4 5 6 7 8) ;;
          config.mdpi) density_value=3; density_alt=(2 4 5 6 7 8) ;;
          config.tvdpi) density_value=4; density_alt=(2 3 5 6 7 8) ;;
          config.hdpi) density_value=5; density_alt=(2 3 4 6 7 8) ;;
          config.xhdpi) density_value=6; density_alt=(2 3 4 5 7 8) ;;
          config.xxhdpi) density_value=7; density_alt=(2 3 4 5 6 8) ;;
          config.xxxhdpi) density_value=8; density_alt=(2 3 4 5 6 7) ;;
        esac
        density_toc
        ;;
      config.$arch)
        arch_value=$(cut -d'.' -f2 <<< $file)
        abi_id=$file
        case $file in
          config.armeabi_v7a) abi_value=2; abi_variant=(3 4 5) ;;
          config.arm64_v8a) abi_value=3; abi_variant=(2 4 5) ;;
          config.x86) abi_value=4; abi_variant=(2 3 5) ;;
          config.x86_64) abi_value=5; abi_variant=(2 3 4) ;;
        esac
        abi_toc
        ;;
      config.$language_value) language_id=$file; language_toc ;;
    esac
  done
  # proto end of modules block text
  cat >> toc.txt << EOF
}
EOF

  # proto version naming modules text
  cat >> toc.txt << EOF
modules {
  splits {
    apk_path: "$versionName"
  }
}
EOF

  # proto bin
  protoc --encode=android.bundle.Toc --proto_path=. toc.proto < toc.txt > toc.pb && rm -f toc.proto toc.txt
}
###########################################################################################################