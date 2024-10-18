# Victorware 2.0

Welcome to my `Victorware 2.0`. This is the home of the Anki Vector robot's source code. Original README: [README-orig.md](/README-orig.md)

## Branch Info

This branch is based off of the 'snowboy' branch and is able to have its wake word changed to something else.

The main purpose of this branch is to attempt to make a modern version of the old cozmoware but with a newer underlying os.

Currently the wake-word is still "hey vector" but this will be changed to "hey cozmo".

## Building (Linux)

 - Prereqs: Make sure you have `docker` and `git-lfs` installed.

1. Clone the repo and cd into it:

```
cd ~
git clone --recurse-submodules https://github.com/kercre123/victor -b SWMODDER/Victorware-2.0
cd victor
git lfs install
git lfs pull
```

2. Make sure you can run Docker as a normal user. This will probably involve:

```
sudo groupadd docker
sudo gpasswd -a $USER docker
newgrp docker
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock
```

3. Run the build script:
```
cd ~/victor
./wire/build-d.sh
```

3. It should just work! The output will be in `./_build/vicos/Release/`

## Building (Intel macOS)

 - Prereqs: Make sure you have [brew](https://brew.sh/) installed.
   -  Then: `brew install pyenv git-lfs ccache`

1. Clone the repo and cd into it:

```
cd ~
git clone --recurse-submodules https://github.com/kercre123/victor -b snowboy
cd victor
git lfs install
git lfs pull
```

2. Set up Python 2:

```
pyenv install 2.7.18
pyenv init
```

- Add the following to both ~/.zshrc and ~/.zprofile:
```
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
pyenv shell 2.7.18
```


3. Run the build script:
```
cd ~/victor
./wire/build.sh
```

3. It should just work! The output will be in `./_build/vicos/Release/`

## Deploying

1. Echo your robot's IP address to robot_ip.txt (in the root of the victor repo):

```
echo 192.168.1.150 > robot_ip.txt
```

2. Copy your bot's SSH key to a file called `robot_sshkey` in the root of this repo.

3. Run:

```
# Linux
./wire/deploy-d.sh

# macOS
./wire/deploy.sh
```
Hopefully one day you'll see the beautiful cozmo eyes instead of  Vector's.