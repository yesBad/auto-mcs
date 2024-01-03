#!/bin/bash


# Global variables
shopt -s expand_aliases
python_path="/opt/python/3.9.18"
python=$python_path"/bin/python3.9"
venv_path="./venv"
current=$( pwd )



# Check for a set DISPLAY variable
if [ ${DISPLAY:-"unset"} == "unset" ]; then
	echo A desktop environment is required to proceed
	exit 1
fi


# First, check if a valid version of Python 3.9 is installed
version=$( $python --version )
errorlevel=$?
if [ $errorlevel -ne 0 ]; then
	echo Obtaining packages to build Python from source

	# Determine system package manager and install appropriate packages
	if [ -x "$(command -v apk)" ];       then sudo apk add --no-cache wget gcc make zlib-dev libffi-dev openssl-dev musl-dev portaudio-dev gstreamer-dev sdl2_mixer-dev sdl2_ttf-dev pangomm-dev sdl2_image-dev pkgconfig
	elif [ -x "$(command -v apt-get)" ]; then sudo apt-get install -y build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev liblzma-dev tk-dev python3-dev portaudio19-dev
	elif [ -x "$(command -v dnf)" ];     then sudo dnf -y groupinstall "Development Tools" && sudo dnf -y install wget gcc openssl-devel bzip2-devel libffi-devel xz-devel tk-devel portaudio-devel
	elif [ -x "$(command -v yum)" ];  then sudo yum	-y groupinstall "Development Tools" && sudo dnf -y install wget gcc openssl-devel bzip2-devel libffi-devel xz-devel tk-devel portaudio-devel
	elif [ -x "$(command -v pacman)" ];  then sudo pacman -S --noconfirm base-devel wget tk tcl openssl portaudio
	else echo "Package manager not found: You must manually install the Python 3.9 source dependencies">&2; fi


    echo Installing Python 3.9

	cd /tmp/
	wget https://www.python.org/ftp/python/3.9.18/Python-3.9.18.tgz
	tar xzf Python-3.9.18.tgz
	cd Python-3.9.18

	sudo mkdir -p $python_path/lib
	sudo ./configure --prefix=$python_path --enable-optimizations --with-lto --with-computed-gotos --with-system-ffi --enable-shared LDFLAGS="-Wl,-rpath $python_path/lib"
	sudo make -j "$(nproc)"

	# sudo ./python3.9 -m test -j "$(nproc)"
	sudo make altinstall
	sudo rm /tmp/Python-3.9.18.tgz

	sudo $python -m pip install --upgrade pip setuptools wheel

	errorlevel=$?
	if [ $errorlevel -ne 0 ]; then
    	echo "Something went wrong installing Python, please try again (did you install all the packages?)"
    	exit 1
   	fi

fi



# If Python 3.9 is installed and a DE is present, check for a virtual environment
cd $current
echo Detected $version

if ! [ -d $venv_path ]; then
	echo "A virtual environment was not detected"
	$python -m venv $venv_path

else
	echo "Detected virtual environment"
fi



# Install/Upgrade packages
echo "Installing packages"
source $venv_path/bin/activate
pip install --upgrade -r ./reqs-linux.txt



# Patch and install Kivy hook for Pyinstaller
patch() {
	kivy_path=$1"/python3.9/site-packages/kivy/tools/packaging/pyinstaller_hooks"
	sed 's/from PyInstaller.compat import modname_tkinter/#/' $kivy_path/__init__.py > tmp.txt && mv tmp.txt $kivy_path/__init__.py
	sed 's/excludedimports = \[modname_tkinter, /excludedimports = [/' $kivy_path/__init__.py > tmp.txt && mv tmp.txt $kivy_path/__init__.py
	$venv_path/bin/python3.9 -m kivy.tools.packaging.pyinstaller_hooks hook $kivy_path/kivy-hook.py
}
patch $venv_path"/lib"
patch $venv_path"/lib64"



# Build
export KIVY_AUDIO=ffpyplayer
pyinstaller ./auto-mcs.linux.spec --upx-dir ./upx/linux --clean
deactivate
echo Done! Compiled binary:  \"./dist/auto-mcs\"
