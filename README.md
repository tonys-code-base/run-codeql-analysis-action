# CodeQL Scan Action

Run [CodeQL](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning-with-codeql) scan for a list of supplied input languages and upload output SARIF file to GitHub. This action is more geared for anyone seeking to run automated CodeQL scans on self-hosted runners.

Limited testing has been carried out using a self-hosted runner installed on an `Ubuntu Jammy` `amd-64` OS. For the action to work correctly, the following packages need to be installed on the runner OS:

- [CodeQL CLI](https://docs.github.com/en/code-security/codeql-cli/getting-started-with-the-codeql-cli/setting-up-the-codeql-cli)

- [Apache Maven](https://maven.apache.org/install.html)

- NodeJS v18 ([following the GitHub-hosted installation default](https://github.com/actions/runner-images/blob/9d5d1be4828f3f7e54796a46d60afd0a2f9e05b0/images/ubuntu/toolsets/toolset-2204.json#L313))

- [jq](https://jqlang.github.io/jq/)

  ```sudo apt install jq
  sudo apt install jq
  ```

## Note on CodeQL usage with Private Repositories

To use the action for scanning private repositories, a [GitHub Advanced Security License](https://docs.github.com/en/get-started/learning-about-github/about-github-advanced-security#about-advanced-security-features) is required otherwise you will see the following message appear in the workflow logs:

```
{"message":"Advanced Security must be enabled for this repository to use code scanning..."
```

## Supported Languages

### Non-compilable

- `python`, `javascript`, `typescript`, `ruby`

### Compiled

- `java`

**Note:** 

- Given the nature of the build process for compiled languages, attempting to cover the anticipated range of build command/mode combinations can be extremely time consuming, as such, the action might need further tweaking
- Feel free to log any issues you come across

## Inputs

Most inputs mirror the parameters passed to the [CodeQL CLI commands](https://docs.github.com/en/code-security/codeql-cli/codeql-cli-manual). The descriptions listed below were sourced from [CodeQL CLI manual](https://docs.github.com/en/code-security/codeql-cli/codeql-cli-manual)

| Parameter          | Description                                                  | Required ? | Default             |
| ------------------ | :----------------------------------------------------------- | ---------- | :------------------ |
| git_ref            | Name of the ref to perform the analysis against. If this ref is a pull request merge commit, then use *refs/pulls/1234/merge* or *refs/pulls/1234/head* (depending on whether or not this commit corresponds to the HEAD or MERGE commit of the PR) | false      | `${{ github.ref }}` |
| commit_sha         | SHA value of the commit being analyzed                       | false      | `${{ github.sha }}` |
| language_to_scan   | The source language(s) identifier to carry out the scan against:<br/>Example,<br/> - to scan for a single language (such as `python`): `"python"`.<br/> - to scan multiple languages (such as `python` and `javascript`): `"python,javascript"`<br/>Use [codeql resolve languages](https://docs.github.com/en/code-security/codeql-cli/codeql-cli-manual/resolve-languages) to get a list of the pluggable language extractors found on the search path. | true       |                     |
| token              | Value can be access from secrets context `${{ secrets.GITHUB_TOKEN }}` | true       |                     |
| codeql_scan_type   | [Query suite](https://docs.github.com/en/code-security/codeql-cli/codeql-cli-manual/database-analyze#querysuitepack) to suite to execute | false      | `code-scanning`     |
| build_mode         | [Build mode](https://docs.github.com/en/code-security/codeql-cli/codeql-cli-manual/database-create#--build-modemode) to use for creating the CodeQL DB. Used for compiled languages | false      | `''`                |
| build_command      | Used for compiled languages. [Build command](https://docs.github.com/en/code-security/codeql-cli/codeql-cli-manual/database-create#-c---commandcommand) or script that invokes the build process for the codebase | false      | `''`                |
| codeql_config_file | Path to CodeQL [code scanning configuration file](https://docs.github.com/en/code-security/codeql-cli/codeql-cli-manual/database-create#--codescanning-configfile) | false      | `''`                |

## Output

| Parameter            | Description                                |
| -------------------- | ------------------------------------------ |
| cql_sarif_output_log | Log returned from `sarif` upload to GitHub |

## Usage

### Example 1: Run the action for `java` language analysis.

```yaml
...
...
jobs:
  run-codeql-scan:
    runs-on: [self-hosted]
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'
          ## if you need to generate a specific Maven settings.xml config file
          ## refer to: https://docs.github.com/en/actions/publishing-packages/publishing-java-packages-with-maven
          ...
          ...

      - name: Run the scan against the codebase
        id: run-scan
        uses: tonys-code-base/run-codeql-analysis-action@master
        with:
          language_to_scan: java
          token: ${{ secrets.GITHUB_TOKEN }}
```

### Example 2: Run the action for `java` and `python` analysis.

Extend the last step in the previous example as follows:

```yaml
...
...
- name: Run the scan against the codebase
  id: run-scan
  uses: tonys-code-base/run-codeql-analysis-action@master
  with:
    ## comma separated list of languages to scan
    language_to_scan: "java,python"
```
