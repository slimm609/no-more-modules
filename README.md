# No More Modules

Instead of linking git submodules to your repo, sync them into the repo while still being able to update mainstream and fetch changes.

git submodules have several problems that can make them difficult to maintain and manage, including when used in CI/CD tools.

* You can’t only git clone the repository. You have to clone the repo, then run `git submodule init` and `git submodule update`
* You can't download an archive of all the code,  You have to download it, then download each module by itself.
* Forking becomes very difficult when using submodules, you need to update submodule associations and also make sure they have proper access to each module.
* Including submodules that have their own submodules can run into issues when trying to clone and sync.


## Installation

Copy `nmm.sh` and `nmm.conf` to the repo,  if you want to copy it to a location other than the root of the repository, you must update the config path in `nmm.sh`.

## Getting Started

edit the config file to add the submodules that you want to sync. `nmm.conf`

### list modules
```
nmm.sh --list
```

### sync all modules
```
nmm.sh --syncall
```

### sync single module
```
nmm.sh --sync=modulename
```



### Examples

example-sync directory includes multiple examples of synced repos that could be submodules.

example-nested-submodule includes a repo with its own submodule.