# issue-link

Get the link to JIRA/Tracker/GitHub etc... bugs, features & issues. Turn their IDs into buttons.

## Usage

`issue-link` has built in support for:

* GitHub
* Bitbucket
* GitLab

Other services [must be configured](#adding-issue-id-formats).

### Turning Issue IDs Into Buttons

To turn issue IDs into buttons that link to the issue activate `issue-link-mode`:

```el
;; Or wherever you want issue IDs to be turned into buttons
(add-hook 'prog-mode-hook 'issue-link-mode)
```

Buttons will be created from text matching `issue-link-issue-regexp`
and `issue-link-issue-alist`.

URLs are created by matching text against patterns in `issue-link-issue-alist` or, if none matches,
by using the current branch's remote (currently only Git is supported).

### Getting an Issue's Link

To get the link for an issue or the issue associated with the current branch run `M-x issue-link`
or bind it to the keys of your choice e.g., `(global-set-key (kbd "C-c i") 'issue-link)`.

The command will add the link to the kill ring and/or open the issue in your browser. To control this
behavior see `issue-link-kill` and `issue-link-open-in-browser`.

With a prefix argument or, if `issue-link-issue-alist` is not set, prompt for an issue ID.

### Adding Issue ID Formats

To support issues in systems like JIRA and Pivotal Tracker you must configure `issue-link-issue-alist`.
The first element is a regexp to match an issue ID and the second is the URL where the issue
can be viewed. `%s` will be replaced with the matched ID:

```el
(add-to-list 'issue-link-issue-alist
             '("\\<KEY-[[:word:]]+\\>" "https://your-org.atlassian.net/browse/%s"))

(add-to-list 'issue-link-issue-alist
             '("#[0-9]+\\>" "https://www.pivotaltracker.com/story/show/%s"))

```

## Org Mode

`issue-link` can add an Org mode link type of `issue:`. This allows you to insert
issue links using `org-issue-link`. To use this add the following function call to your config:

```el
(issue-link-add-org-link-type)
```

This can also be called interactively.

## See Also

### Emacs

* [git-link](https://github.com/sshaw/git-link) - get the GitHub/Bitbucket/GitLab/... URL for a buffer location
* [button-lock](https://github.com/rolandwalker/button-lock) - easily create clickable & mouseable text
* [build-status](https://github.com/sshaw/build-status) - monitors and shows a buffer's build status in the mode line
* [copy-as-format](https://github.com/sshaw/copy-as-format) - copy buffer locations as GitHub/Slack/JIRA/HipChat/... formatted code

### Google Chrome

* [Jirafy](https://chrome.google.com/webstore/detail/jirafy/npldkpkhkmpnfhpmeoahhakbgcldplbj) - linkifies JIRA ticket numbers on select pages
* [Quick JIRA](https://chrome.google.com/webstore/detail/quick-jira/acdnmaeifljongleeegkkfnfcopblokj) - quickly open a JIRA issue
