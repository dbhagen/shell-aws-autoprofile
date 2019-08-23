# ZSH-AWS-AUTOPROFILE Add-On
If you're like me, you develop in a number of different AWS accounts or profiles. Having to make sure I'm currently using the correct one can be a pain. I wrote this script so that I could store a simple file with my project directory to make sure I'm always connecting to the write environment while working. Major thanks to the NVM team, as the config lookup functions were directly copied from their code and modified.

## Installation
Download the `zsh-aws-autoprofile.zsh` file and store it either in your home folder, or somewhere you organize ZSH/Prompt configuration. For my example, I'll just store it in my home folder.

```
git clone 
TODO:
```

## Usage
ZSH-AWS-AUTOPROFILE is a small add-on to ZSH that allows the environment variable `AWS_PROFILE` to be set via a `.awsprofile` file in the current working directory, or a parent there of. Failing that, it will look in the current user's `$HOME` folder for a `.awsprofile` file.

The content of this file should be the profile name, one of the ones found in your `$HOME/.aws/credentials` file, per the AWS CLI configuration.

I highly recommend this with a ZSH prompt that displays the current AWS profile.

## Version Control

Depending on your environment, you may want to add `.awsprofile` to your `.gitignore` so that the file doesn't travel to other systems. While you may call your profile something like `<companyname>-<projectname>-<rolename>`, another contributor might call it `<companyname>-<rolename>-<projectname>`, causing it to not work, conflict, or just leave the environment confusing.

On the other hand, having this in a build environment might allow you to consistently change between profiles if needed.

## Disclaimer
The standard. Use at your own risk, your milage may vary, and please use it for good and not evil. I'm not responsible for anything you do with it.