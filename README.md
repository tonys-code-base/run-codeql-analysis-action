# CodeQL Scan Action

Run [CodeQL](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning-with-codeql) scan for a list of supplied input languages and upload output SARIF file to GitHub. This action is more geared for anyone seeking to run automated CodeQL scans on self-hosted runners.

Limited testing has been performed using a self-hosted runner installed on an `Ubuntu Jammy` `amd-64` OS. For the action to work correctly, the following packages need to be installed on the self-hosted runner OS:

- [CodeQL CLI](https://docs.github.com/en/code-security/codeql-cli/getting-started-with-the-codeql-cli/setting-up-the-codeql-cli)
- [Apache Maven](https://maven.apache.org/install.html)
- NodeJS v18 ([following the GitHub-hosted installation default](https://github.com/actions/runner-images/blob/9d5d1be4828f3f7e54796a46d60afd0a2f9e05b0/images/ubuntu/toolsets/toolset-2204.json#L313))

To use the action with private repositories, a [GitHub Advanced Security License](https://docs.github.com/en/get-started/learning-about-github/about-github-advanced-security#about-advanced-security-features) is required otherwise you will see the following message appear in the workflow logs:

```
{"message":"Advanced Security must be enabled for this repository to use code scanning..."
```

## Supported Languages

**_Note:_**

- The action has been tested with a self-hosted runner installed on an `Ubuntu Jammy` `amd-64` OS
- **_Given the shear number of language variations, and the nature of the build process for compiled languages, exhaustive testing can be extremely time consuming, therefore, consider this release as `alpha`, at best_**
- Currently, scanning is supported for _only_ the following languages:
  - `python`, `javascript`, `typescript`, `java`

## Inputs

| Parameter          | Description                                                                                                                                                                                                                        | Required ? | Default             |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------- |
| git_ref            | Git ref to perform the CodeQL scan against                                                                                                                                                                                         | false      | `${{ github.ref }}` |
| commit_sha         | SHA value of the commit being analyzed                                                                                                                                                                                             | false      | `${{ github.sha }}` |
| language_to_scan   | The source language(s) to carry out the scan against:<br/>Example,<br/> - to scan for a single language (such as python): `"python"`.<br/> - to scan multiple languages (such as `python` and `javascript`): `"python,javascript"` | true       |                     |
| token              | GitHub token                                                                                                                                                                                                                       | true       |                     |
| codeql_scan_type   | [Query suite](https://docs.github.com/en/code-security/codeql-cli/codeql-cli-manual/database-analyze#querysuitepack) to use for the analysis                                                                                       | false      | `code-scanning`     |
| build_mode         | [Build mode](https://docs.github.com/en/code-security/codeql-cli/codeql-cli-manual/database-create#--build-modemode) to use for creating the CodeQL DB. Used for compiled languages                                                | false      | `''`                |
| build_command      | Used for compiled languages. [Build command](https://docs.github.com/en/code-security/codeql-cli/codeql-cli-manual/database-create#-c---commandcommand) or script that invokes the build process for the codebase                  | false      | `''`                |
| codeql_config_file | Path to CodeQL [code scanning configuration file](https://docs.github.com/en/code-security/codeql-cli/codeql-cli-manual/database-create#--codescanning-configfile)                                                                 | false      | `''`                |

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
