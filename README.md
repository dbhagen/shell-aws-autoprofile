# SHELL-AWS-AUTOPROFILE Add-On
If you're like me, you develop in a number of different AWS accounts or profiles. Having to make sure I'm currently using the correct one can be a pain. I wrote this script so that I could store a simple file with my project directory to make sure I'm always connecting to the correct environment while working. Major thanks to the NVM team, as the config lookup functions were directly copied from their code and modified.

Example prompt
![Example Prompt](https://raw.githubusercontent.com/dbhagen/shell-aws-autoprofile/master/example.png)

## Installation
### (NEW!) BASH
Now with BASH capability!
```
git clone git@github.com:dbhagen/shell-aws-autoprofile.git ~/shell-aws-autoprofile

# Manually install it in your .bashrc file, or run this command to programmatically append it to the file.

printf "\nsource '${HOME}/shell-aws-autoprofile/shell-aws-autoprofile.sh'\n" >> ~/.bashrc
```

### [Oh-My-ZSH](https://github.com/robbyrussell/oh-my-zsh)
Very similar to the plain install, just to the [Oh-My-ZSH](https://github.com/robbyrussell/oh-my-zsh) custom plugin folder.
```
git clone git@github.com:dbhagen/shell-aws-autoprofile.git $ZSH_CUSTOM/plugins/shell-aws-autoprofile
```

Then in your `.zshrc`, add the add-on to the plugin list.
```
plugins=(
  battery
  git
  aws
  shell-aws-autoprofile
)
```

### Plain ZSH
Clone the repository either into your home folder, or somewhere you organize ZSH/Prompt configuration. For my example, I'll just store it in my home folder.

```
git clone git@github.com:dbhagen/shell-aws-autoprofile.git ~/shell-aws-autoprofile

# Manually install it in your .zshrc file, or run this command to programmatically append it to the file.

echo "\nsource '${HOME}/shell-aws-autoprofile/shell-aws-autoprofile.sh'\n" >> ~/.zshrc
```

## Usage
SHELL-AWS-AUTOPROFILE is a small add-on to BASH and ZSH that allows the environment variables `AWS_PROFILE` and `AWS_REGION` to be set via a `.awsprofile` file in the current working directory, or a parent thereof. Failing that, it will look in the current user's `$HOME` folder for a `.awsprofile` file.

### The `.awsprofile` file
The file is plain text. Line 1 is the profile name, line 2 an optional region:

```
my-company-profile
us-east-1
```

- **Line 1 — AWS profile name.** Should match one of the profiles found in `$HOME/.aws/credentials`.
- **Line 2 — AWS region (optional).** If present, it is applied as `AWS_REGION`; if line 2 is missing or empty, `AWS_REGION` is left untouched.
- **Extra lines are ignored.** Only the first two lines are ever read.
- **Windows-style (CRLF) line endings are tolerated.** A trailing carriage return is stripped from each line.

### Lookup order
Whenever you change directory (and once when your shell starts), the add-on looks for a `.awsprofile` file:

1. in the current directory, then
2. in each parent directory, walking upward to the filesystem root, then
3. in your `$HOME` directory.

The nearest file wins — a project's own `.awsprofile` always beats one higher up the tree or in `$HOME`. If no `.awsprofile` is found anywhere, the add-on prints `No .awsprofile file found` and leaves `AWS_PROFILE` and `AWS_REGION` exactly as they were.

### The reserved `none` profile
Setting line 1 to the exact string `none` is reserved: it clears `AWS_PROFILE` (resets it to the empty string), letting you opt a directory tree out of automatic profile selection.

```
none
us-east-1
```

The region on line 2 is still honored, so `none` plus a region gives you an `AWS_REGION` with no `AWS_PROFILE`. By default, the add-on prints an alert when an explicit `none` profile is applied; setting `AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE=true` in your environment suppresses that alert message.

### Environment variables
The add-on exports:

| Variable | Set to |
| --- | --- |
| `AWS_PROFILE` | The profile from line 1; empty when the profile is `none`. |
| `AWS_REGION` | The region from line 2, when one is present. |
| `AWSPROFILE_CONFIG_PROFILE` | The profile name exactly as read from the matched `.awsprofile` file (introspection; empty when no profile applies). |
| `AWSREGION_CONFIG_REGION` | The region exactly as read from the matched `.awsprofile` file (introspection; empty when no region applies). |

### Two copies of the script, one rule
`shell-aws-autoprofile.sh` is the copy you source for Bash and plain ZSH installs; `shell-aws-autoprofile.plugin.zsh` is the copy Oh My Zsh loads from the custom plugins folder. The two files are byte-for-byte identical — if you change one, mirror the change in the other so every install method behaves the same.

I highly recommend this with a ZSH ([Oh-My-ZSH](https://github.com/robbyrussell/oh-my-zsh)+[Spaceship Prompt](https://github.com/denysdovhan/spaceship-prompt)) or BASH ([BASH-IT](https://github.com/Bash-it/bash-it)) prompt that displays the current AWS profile.

## Version Control

Depending on your environment, you may want to add `.awsprofile` to your `.gitignore` so that the file doesn't travel to other systems. While you may call your profile something like `<companyname>-<projectname>-<rolename>`, another contributor might call it `<companyname>-<rolename>-<projectname>`, causing it to not work, conflict, or just leave the environment confusing.

On the other hand, having this in a build environment might allow you to consistently change between profiles if needed.

## Disclaimer
The standard. Use at your own risk, your mileage may vary, and please use it for good and not evil. I'm not responsible for anything you do with it.

## Credits
Thanks to [@laggardkernel](https://github.com/laggardkernel) for his [GIST snippet](https://gist.github.com/laggardkernel/6cb4e1664574212b125fbfd115fe90a4), and [NVM](https://github.com/nvm-sh/nvm) for the Find-Up functions.
