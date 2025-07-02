from cumulusci.tasks.salesforce.sourcetracking import RetrieveChanges
from cumulusci.utils import process_text_in_directory
import os
import re

class RetrieveChanges(RetrieveChanges):
    """Retrieves changed components from a scratch org while preserving specified tokens."""

    task_options = RetrieveChanges.task_options.copy()
    task_options["preserve_tokens"] = {
        "description": "Comma-separated list of tokens to preserve (e.g. __PROJECT_NAME__,__PROJECT_LABEL__)",
        "required": False,
    }

    def _init_options(self, kwargs):
        super()._init_options(kwargs)
        self.tokens_to_preserve = []
        if "preserve_tokens" in self.options:
            self.tokens_to_preserve = [
                token.strip() for token in self.options["preserve_tokens"].split(",")
            ]

    def _run_task(self):
        # Run the standard retrieve
        super()._run_task()

        # If we have tokens to preserve and the retrieve was successful
        if self.tokens_to_preserve and os.path.exists(self.options["path"]):
            self._preserve_tokens()

    def _preserve_tokens(self):
        """Process files to preserve specified tokens"""
        def process_file(filename, content):
            # Store original tokens and their values
            token_values = {}
            for token in self.tokens_to_preserve:
                # Create a pattern that matches the token in filenames
                token_in_name = re.search(re.escape(token), filename)
                if token_in_name:
                    # Store the resolved value
                    resolved_part = filename[token_in_name.start():token_in_name.end()]
                    token_values[resolved_part] = token

                # Create a pattern that matches the token in content
                token_in_content = re.search(re.escape(token), content)
                if token_in_content:
                    # Store the resolved value
                    resolved_part = content[token_in_content.start():token_in_content.end()]
                    token_values[resolved_part] = token

            # Replace resolved values back with tokens
            new_content = content
            new_name = filename
            for resolved, token in token_values.items():
                new_content = new_content.replace(resolved, token)
                new_name = new_name.replace(resolved, token)

            return new_name, new_content

        # Process all files in the directory
        process_text_in_directory(self.options["path"], process_file) 