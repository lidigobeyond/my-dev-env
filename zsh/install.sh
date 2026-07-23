ln -s ./zsh_aliases ~/.zsh_aliases

echo '# Include personal aliases if the file exists
if [ -f ~/.zsh_aliases ]; then
  ### CUSTOM ALIAS START ###
  source ~/.zsh_aliases
  ### CUSTOM ALIAS END ###
fi' >> ~/.zshrc
