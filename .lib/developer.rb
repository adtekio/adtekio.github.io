class Developer
  def work_on_ticket(ticket)
    # dev branch name
    # issue_number prefix is used by a git hook to add
    # "refs #{number}" commit comment for redmine
    ticket_branch = "issue_#{ticket.number}_#{ticket.title}"

    # merge lastet changes from production
    # repo and branch
    cmd.execute "git pull origin master"

    # create local development branch
    cmd.execute "git checkout -b #{ticket_branch}"
    [1..n].times do
      work_on_ticket
      cmd.execute "git commit -m, 'changeset description'" # 'refs ticketnumer' is added be hoook
    end
    # push to remote (for backup)
    cmd.execute "git push #{username} ticket_branch"

    # prepare changes for review:
    # get latest updates from master
    cmd.execute "git checkout master"
    cmd.execute "git pull origin master"
    
    # we merge and squash commits in single commit, to make review more convenient
    cmd.execute "git checkout -b #{ticket_branch}_squashed"
    cmd.execute "git merge --squash #{ticket_branch}"

    fix_merge_conflicts

    result = cmd.execute "git commit -m 'commit summary'"
    review_commit_id = result.parse.commit_id

    # push to remote for review
    cmd.execute "git push #{username} #{ticket_branch}_squash"
    
    ticket.add_comment "for reviews, see commit:#{review_commit_id}"
    ticket.status = "review"
    ticket.assignee = other_developer
  end
end
