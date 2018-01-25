import qbs
import qbs.FileInfo
import QtMultiplexConfig
import QtUtils

Product {
    property bool hostBuild: false

    Depends { name: "cpp" }
    Depends { name: "osversions" }
    Depends { name: "Android.ndk"; condition: qbs.targetOS.contains("android") }

    Depends { name: "QtGlobalConfig" }
    Depends { name: "QtGlobalPrivateConfig" }

    Depends { name: mkspecModule; condition: mkspecModule !== undefined } // TODO: Explicit comparison should not be needed, but is

    property bool targetsUWP: mkspec.startsWith("winrt-")
    property string mkspec: hostBuild ? QtMultiplexConfig.hostMkspec
                                      : QtMultiplexConfig.targetMkspec
    property string mkspecModule: QtUtils.qmakeMkspecToQbsModule(mkspec)
    property string hostProfile: "qt_hostProfile"
    property string targetProfile: "qt_targetProfile"
    qbs.profiles: [hostBuild ? hostProfile : targetProfile]

    aggregate: {
        if (!qbs.targetOS.contains("darwin"))
            return false;
        var multiplexProps = multiplexByQbsProperties;
        if (multiplexProps.contains("architectures")) {
            var archs = qbs.architectures;
            if (archs && archs.length > 1)
                return true;
        }
        if (multiplexProps.contains("buildVariants")) {
            var variants = qbs.buildVariants;
            return variants && variants.length > 1;
        }
        return false;
    }

    multiplexByQbsProperties: {
        var result = ["profiles"];
        if (qbs.targetOS.contains("darwin"))
            result.push("architectures");
        if (project.debugAndRelease)
            result.push("buildVariants");
        return result;
    }

    qbs.architectures: hostBuild ? original : project.targetArchitecture
    qbs.buildVariants: project.debugAndRelease ? ["debug", "release"] : []

    Properties {
        condition: qbs.targetOS.contains("android")
        Android.ndk.appStl: "gnustl_shared"
    }

// TODO: This belongs into the top-level mkspec module
    cpp.cxxLanguageVersion: {
        if (hostBuild)
            return "c++11"; // TODO: What is the correct way to get this information?
        if (QtGlobalConfig.c__1z)
            return "c++1z";
        if (QtGlobalConfig.c__14)
            return "c++14";
        if (QtGlobalConfig.c__11)
            return "c++11";
        return undefined;
    }

    cpp.cxxStandardLibrary: {
        if (qbs.toolchain.contains("clang")) {
            if (qbs.targetOS.contains("darwin"))
                return "libc++";
            if (qbs.targetOS.contains("linux"))
                return "libstdc++";
        }
        return base;
    }

    property stringList commonCppDefines: []
    cpp.defines: {
        var defines = commonCppDefines.concat([
            "_USE_MATH_DEFINES",
        ]);
        if (cpp.platformDefines)
            defines = defines.concat(cpp.platformDefines);
        return defines;
    }

    cpp.includePaths: [
        project.qtbaseDir + "/mkspecs/" + mkspec,
        product.buildDirectory + "/.uic", // TODO: Export from uic product
        project.buildDirectory + "/include",
    ]

    Properties {
        condition: qbs.toolchain.contains("gcc") && project.rpath
        cpp.sonamePrefix: qbs.targetOS.contains("darwin") ? "@rpath" : undefined
        cpp.rpaths: qbs.installRoot + "/lib"
    }

    Properties {
        condition: qbs.toolchain.contains("gcc") && !hostBuild
        cpp.toolchainPrefix: QtMultiplexConfig.toolchainPrefix
    }

    Rule {
        inputs: "uic"
        Artifact {
            fileTags: "hpp"
            filePath: product.buildDirectory + "/.uic/ui_" + input.baseName + ".h"
        }
        prepare: {
            var installRoot = product.moduleProperty("qbs", "installRoot");
            var installPrefix = product.moduleProperty("qbs", "installPrefix");
            var cmd = new Command(FileInfo.joinPaths(installRoot, installPrefix, "bin/uic"),
                ["-o", output.filePath, input.filePath]);
            cmd.description = "uic " + input.fileName;
            cmd.highlight = "codegen";
            return cmd;
        }
    }

    FileTagger {
        patterns: "*.ui"
        fileTags: "uic"
    }

    Export {
        Depends { name: "cpp" }
        cpp.defines: product.commonCppDefines
    }
}