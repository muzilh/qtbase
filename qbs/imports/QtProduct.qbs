import qbs
import qbs.FileInfo
import QtMultiplexConfig
import QtUtils

Product {
    property bool hostBuild: false

    Depends { name: "Qt.global" }
    Depends { name: "cpp" }
    Depends { name: "osversions" }
    Depends { name: "Android.ndk"; condition: qbs.targetOS.contains("android") }

    Depends { name: mkspecModule; condition: mkspecModule !== undefined } // TODO: Explicit comparison should not be needed, but is

    property bool targetsUWP: mkspec.startsWith("winrt-")
    property bool targetsAndroidProper: qbs.targetOS.contains("android")
                                        && !Qt.global.config.android_embedded
    readonly property bool hasUiKit: qbs.targetOS.containsAny(["ios", "tvos", "watchos"])
    property string mkspec: hostBuild ? QtMultiplexConfig.hostMkspec
                                      : QtMultiplexConfig.targetMkspec
    property string mkspecModule: QtUtils.qmakeMkspecToQbsModule(mkspec)
    property string hostProfile: "qt_hostProfile"
    property string targetProfile: "qt_targetProfile"
    qbs.profile: hostBuild ? hostProfile : targetProfile    // for aggregate products
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

    Properties {
        condition: qbs.toolchain.contains("mingw")
        cpp.minimumWindowsVersion: "6.1"
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
            "QT_NO_NARROWING_CONVERSIONS_IN_CONNECT",
        ]);
        if (qbs.buildVariant === "release")
            defines.push("QT_NO_DEBUG");
        if (cpp.platformDefines)
            defines = defines.concat(cpp.platformDefines);
        return defines;
    }

    cpp.includePaths: [
        project.qtbaseDir + "/mkspecs/" + mkspec,
        project.buildDirectory + "/include",
    ]

    Properties {
        condition: qbs.toolchain.contains("gcc") && !hostBuild
        cpp.toolchainPrefix: QtMultiplexConfig.toolchainPrefix
    }

    Export {
        Depends { name: "cpp" }
        cpp.defines: product.commonCppDefines
    }
}
