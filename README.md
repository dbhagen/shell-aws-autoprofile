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
SHELL-AWS-AUTOPROFILE is a small add-on to BASH and ZSH that allows the environment variables `AWS_PROFILE` and `AWS_REGION` to be set via a `.awsprofile` file in the current working directory, or a parent there of. Failing that, it will look in the current user's `$HOME` folder for a `.awsprofile` file.

Contents of this file should contain 2 lines:
 - profile name on line 1 (should match one of the profiles found in `$HOME/.aws/credetials`)
 - region name on line 2

I highly recommend this with a ZSH ([Oh-My-ZSH](https://github.com/robbyrussell/oh-my-zsh)+[Spaceship Prompt](https://github.com/denysdovhan/spaceship-prompt)) or BASH ([BASH-IT](https://github.com/Bash-it/bash-it)) prompt that displays the current AWS profile.

## Version Control

Depending on your environment, you may want to add `.awsprofile` to your `.gitignore` so that the file doesn't travel to other systems. While you may call your profile something like `<companyname>-<projectname>-<rolename>`, another contributor might call it `<companyname>-<rolename>-<projectname>`, causing it to not work, conflict, or just leave the environment confusing.

On the other hand, having this in a build environment might allow you to consistently change between profiles if needed.

## Disclaimer
The standard. Use at your own risk, your milage may vary, and please use it for good and not evil. I'm not responsible for anything you do with it.

## Credits
Thanks to [@laggardkernel](https://github.com/laggardkernel) for his [GIST snippet](https://gist.github.com/laggardkernel/6cb4e1664574212b125fbfd115fe90a4), and [NVM](https://github.com/nvm-sh/nvm) for the Find-Up functions.
