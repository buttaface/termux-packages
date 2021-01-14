TERMUX_PKG_HOMEPAGE=https://swift.org/
TERMUX_PKG_DESCRIPTION="Swift is a high-performance system programming language"
TERMUX_PKG_LICENSE="Apache-2.0, NCSA"
TERMUX_PKG_MAINTAINER="@buttaface"
TERMUX_PKG_VERSION=5.4
SWIFT_RELEASE="DEVELOPMENT-SNAPSHOT-2021-02-12-a"
TERMUX_PKG_SRCURL=https://github.com/apple/swift/archive/swift-$TERMUX_PKG_VERSION-$SWIFT_RELEASE.tar.gz
TERMUX_PKG_SHA256=2356017e924476a09ce5e9c00d7d0f02042453a0b458881f185b7003644586b0
TERMUX_PKG_HOSTBUILD=true
TERMUX_PKG_DEPENDS="binutils-gold, clang, libc++, ndk-sysroot, libandroid-glob, libandroid-spawn, libcurl, libicu, libicu-static, libsqlite, libuuid, libxml2, libdispatch, llbuild"
TERMUX_PKG_BUILD_DEPENDS="cmake, ninja, perl, pkg-config, python2, rsync"
TERMUX_PKG_BLACKLISTED_ARCHES="i686"
TERMUX_PKG_NO_STATICSPLIT=true
#TERMUX_PKG_QUICK_REBUILD=true

SWIFT_COMPONENTS="autolink-driver;compiler;clang-resource-dir-symlink;swift-remote-mirror;parser-lib;license;sourcekit-inproc;stdlib;sdk-overlay"
SWIFT_TOOLCHAIN_FLAGS="-R --no-assertions --llvm-targets-to-build='X86;ARM;AArch64' -j $TERMUX_MAKE_PROCESSES"
SWIFT_PATH_FLAGS="--build-subdir=. --install-destdir=/ --install-prefix=$TERMUX_PREFIX"
SWIFT_BUILD_FLAGS="$SWIFT_TOOLCHAIN_FLAGS $SWIFT_PATH_FLAGS"

if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
SWIFT_BIN="swift-$TERMUX_PKG_VERSION-$SWIFT_RELEASE-ubuntu20.04"
SWIFT_BINDIR="$TERMUX_PKG_HOSTBUILD_DIR/$SWIFT_BIN/usr/bin"
fi

termux_step_post_get_source() {
	if [ "$TERMUX_PKG_QUICK_REBUILD" = "false" ]; then
		# The Swift build-script requires a particular organization of source directories,
		# which the following sets up.
		mkdir .temp
		mv [a-zA-Z]* .temp/
		mv .temp swift

		declare -A library_checksums
		library_checksums[swift-cmark]=b805e2876232dce5af4c357178f2b3ba0dce925c6ba8305199c8f7bdc5ef053f
		library_checksums[llvm-project]=7128a50c5114143d872a35a98d38bffdb1b0936054ba12832e4d50917a203d23
		library_checksums[swift-corelibs-libdispatch]=540dcad9229ebaecfb1a84f43a12d35fa4e087a2eb0bf9efa7ae6dee48252bb3
		library_checksums[swift-corelibs-foundation]=4bd2feb3f978385d7805e6060b198a4ca66b40b6006c85286aabd6c31acec9f6
		library_checksums[swift-corelibs-xctest]=58ed991ed1167997a2be97c351b12f6a2ec7f3d43b624259f342dfcc4ef909c3
		library_checksums[swift-llbuild]=137603b6925b1ce6dd04a892663b9d43a55f6abdf439f3a5fc2ee12d222c5d5c
		library_checksums[swift-argument-parser]=49acf58c698e2671976820b8baf7ccc74ebedf842007d5e1d7711c2f123b3db1
		library_checksums[Yams]=4b31dfa768206a76cb683a695e611572e62e4aa34cdaa248c5a74509cbccd730
		library_checksums[swift-driver]=99c0bc59883d09b39343de024612ab5f72db9bd7af1be64178035c7aff8d03cb
		library_checksums[swift-tools-support-core]=67ab633b195f34732d75acd7b97434fe458bee038df833dd019eae1212cb36fb
		library_checksums[swift-package-manager]=061b1ec610b0269f5586958d8f0760b7339f5636f47b9082f758938489e6b487

		for library in "${!library_checksums[@]}"; do \
			if [ "$library" = "swift-argument-parser" ]; then
				GH_ORG="apple"
				SRC_VERSION="0.3.0"
				TAR_NAME=$SRC_VERSION
			elif [ "$library" = "Yams" ]; then
				GH_ORG="jpsim"
				SRC_VERSION="3.0.1"
				TAR_NAME=$SRC_VERSION
			else
				GH_ORG="apple"
				SRC_VERSION=$SWIFT_RELEASE
				TAR_NAME=swift-$TERMUX_PKG_VERSION-$SWIFT_RELEASE
			fi

			termux_download \
				https://github.com/$GH_ORG/$library/archive/$TAR_NAME.tar.gz \
				$TERMUX_PKG_CACHEDIR/$library-$SRC_VERSION.tar.gz \
				${library_checksums[$library]}
			tar xf $TERMUX_PKG_CACHEDIR/$library-$SRC_VERSION.tar.gz
			mv $library-$TAR_NAME $library
		done

		mv swift-cmark cmark
		mv swift-llbuild llbuild
		mv Yams yams
		mv swift-package-manager swiftpm

		if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
			termux_download \
				https://swift.org/builds/swift-$TERMUX_PKG_VERSION-branch/ubuntu2004/swift-$TERMUX_PKG_VERSION-$SWIFT_RELEASE/$SWIFT_BIN.tar.gz \
				$TERMUX_PKG_CACHEDIR/$SWIFT_BIN.tar.gz \
				0642c3e3230e1e3faec96b33ad9f2a21cb13ea0a10969e12e8727d5ce815c3da
		fi
	fi
	# The Swift compiler searches for the clang headers so symlink against them.
	export TERMUX_CLANG_VERSION=$(grep ^TERMUX_PKG_VERSION= $TERMUX_PKG_BUILDER_DIR/../libllvm/build.sh | cut -f2 -d=)
}

termux_step_host_build() {
	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
		termux_setup_cmake
		termux_setup_ninja
		termux_setup_standalone_toolchain

		# Natively compile llvm-tblgen and some other files needed later.
		SWIFT_BUILD_ROOT=$TERMUX_PKG_BUILDDIR $TERMUX_PKG_SRCDIR/swift/utils/build-script \
		-R --no-assertions -j $TERMUX_MAKE_PROCESSES $SWIFT_PATH_FLAGS \
		--skip-build-cmark --skip-build-llvm --skip-build-swift --build-toolchain-only \
		--host-cc=$TERMUX_STANDALONE_TOOLCHAIN/bin/clang \
		--host-cxx=$TERMUX_STANDALONE_TOOLCHAIN/bin/clang++

		tar xf $TERMUX_PKG_CACHEDIR/$SWIFT_BIN.tar.gz -C $TERMUX_PKG_HOSTBUILD_DIR
	fi
}

termux_step_pre_configure() {
	export SWIFT_ARCH=$TERMUX_ARCH
	test $SWIFT_ARCH == 'arm' && SWIFT_ARCH='armv7'
	if [ "$TERMUX_PKG_QUICK_REBUILD" = "false" ]; then
		cd llbuild
		# A single patch needed from the existing llbuild package
		patch -p1 < $TERMUX_PKG_BUILDER_DIR/../llbuild/lib-llvm-Support-CmakeLists.txt.patch

		cd ../llvm-project
		patch -p1 < $TERMUX_PKG_BUILDER_DIR/../libllvm/clang-lib-Driver-ToolChain.cpp.patch
		patch -p1 < $TERMUX_PKG_BUILDER_DIR/../libllvm/clang-lib-Driver-ToolChains-Linux.cpp.patch
		cd ..

		sed "s%\@TERMUX_PREFIX\@%${TERMUX_PREFIX}%g" \
		$TERMUX_PKG_BUILDER_DIR/swiftpm-Utilities-bootstrap | \
		sed "s%\@TERMUX_PKG_BUILDDIR\@%${TERMUX_PKG_BUILDDIR}%g" | patch -p1

		if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
			sed "s%\@TERMUX_STANDALONE_TOOLCHAIN\@%${TERMUX_STANDALONE_TOOLCHAIN}%g" \
			$TERMUX_PKG_BUILDER_DIR/swiftpm-android-flags.json | \
			sed "s%\@CCTERMUX_HOST_PLATFORM\@%${CCTERMUX_HOST_PLATFORM}%g" | \
			sed "s%\@TERMUX_HOST_PLATFORM\@%${TERMUX_HOST_PLATFORM}%g" | \
			sed "s%\@TERMUX_PREFIX\@%${TERMUX_PREFIX}%g" | \
			sed "s%\@SWIFT_ARCH\@%${SWIFT_ARCH}%g" > $TERMUX_PKG_BUILDDIR/swiftpm-android-flags.json
		fi
	fi
}

termux_step_make() {
	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
		SWIFT_BUILD_FLAGS="$SWIFT_BUILD_FLAGS --android
		--android-ndk $TERMUX_STANDALONE_TOOLCHAIN --android-arch $SWIFT_ARCH
		--android-icu-uc $TERMUX_PREFIX/lib/libicuuc.so
		--android-icu-uc-include $TERMUX_PREFIX/include/
		--android-icu-i18n $TERMUX_PREFIX/lib/libicui18n.so
		--android-icu-i18n-include $TERMUX_PREFIX/include/
		--android-icu-data $TERMUX_PREFIX/lib/libicudata.so --build-toolchain-only
		--skip-local-build --skip-local-host-install
		--cross-compile-hosts=android-$SWIFT_ARCH --cross-compile-deps-path=$TERMUX_PREFIX
		--native-swift-tools-path=$SWIFT_BINDIR
		--native-clang-tools-path=$TERMUX_STANDALONE_TOOLCHAIN/bin"
	fi

	SWIFT_BUILD_ROOT=$TERMUX_PKG_BUILDDIR $TERMUX_PKG_SRCDIR/swift/utils/build-script \
	$SWIFT_BUILD_FLAGS --xctest -b -p --android-api-level $TERMUX_PKG_API_LEVEL \
	--build-swift-static-stdlib --swift-install-components=$SWIFT_COMPONENTS \
	--llvm-install-components=IndexStore --install-llvm --install-swift \
	--install-libdispatch --install-foundation --install-xctest --install-llbuild \
	--install-swiftpm
}

termux_step_make_install() {
	rm $TERMUX_PREFIX/lib/swift/pm/llbuild/libllbuild.so
	rm $TERMUX_PREFIX/lib/swift/android/lib{dispatch,BlocksRuntime}.so

	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
		mv $TERMUX_PREFIX/glibc-native.modulemap \
			$TERMUX_PREFIX/lib/swift/android/$SWIFT_ARCH/glibc.modulemap
	fi
}
