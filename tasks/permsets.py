import json
from pathlib import Path
from typing import Dict, List, Optional, Union

from cumulusci.core.exceptions import TaskOptionsError
from cumulusci.core.source_transforms.transforms import (
    FindReplaceTransform, 
    FindReplaceSpec,
    FindReplaceTransformOptions
)
from cumulusci.tasks.salesforce.users.permsets import (
    AssignPermissionSets,
    AssignPermissionSetLicenses,
    AssignPermissionSetGroups,
)


class AssignPermissionSetsWithFindReplace(AssignPermissionSets):
    """
    Extends the standard AssignPermissionSets task to add find_replace functionality.
    
    This task allows you to assign permission sets and also perform find and replace operations
    on the permission sets' metadata using the standard transforms pattern.
    
    Example:
        assign_permission_sets:
            class_path: cumulusci.custom.tasks.salesforce.users.permsets.AssignPermissionSetsWithFindReplace
            options:
                api_names: __PROJECT_NAME__Admin
                transforms:
                    - transform: find_replace
                      options:
                          patterns:
                              - find: "__PROJECT_NAME__"
                                replace: $project_config.project__package__name
    """
    
    task_options = {
        **AssignPermissionSets.task_options,
        "transforms": {
            "description": "A list of transformations to apply to the permission sets.",
            "required": False,
        },
    }
    
    def _init_options(self, kwargs):
        super()._init_options(kwargs)
        # Process transforms if provided
        self.transforms = self.options.get("transforms", [])
    
    def _run_task(self):
        # Process any transforms before running the standard task
        if self.transforms:
            self._apply_transforms()
        
        # Run the standard permission set assignment
        super()._run_task()
    
    def _apply_transforms(self):
        """
        Apply transforms to the permission set names before assignment.
        This allows for dynamic replacement of values in permission set names.
        """
        if not self.transforms:
            return
            
        self.logger.info("Applying transforms to permission set names")
        
        # Process each transform
        for transform in self.transforms:
            transform_name = transform.get("transform")
            
            if transform_name == "find_replace":
                self._apply_find_replace(transform.get("options", {}))
    
    def _apply_find_replace(self, options):
        """
        Apply find_replace transform to permission set names.
        """
        patterns = options.get("patterns", [])
        if not patterns:
            return
            
        # Apply each pattern to the api_names
        for i, api_name in enumerate(self.options["api_names"]):
            for pattern in patterns:
                find = pattern.get("find")
                replace = pattern.get("replace")
                
                if find and replace:
                    # Handle dynamic replacement with project config values
                    if isinstance(replace, str) and replace.startswith("$project_config."):
                        attr = replace.replace("$project_config.", "")
                        parts = attr.split("__")
                        value = self.project_config
                        for part in parts:
                            if hasattr(value, part):
                                value = getattr(value, part)
                            elif isinstance(value, dict) and part in value:
                                value = value[part]
                            else:
                                value = None
                                break
                        if value:
                            replace = value
                    
                    # Apply the replacement
                    self.options["api_names"][i] = api_name.replace(find, str(replace))
                    
        self.logger.info(f"Transformed permission set names: {', '.join(self.options['api_names'])}")


class AssignPermissionSetLicensesWithFindReplace(AssignPermissionSetsWithFindReplace, AssignPermissionSetLicenses):
    """
    Extends the standard AssignPermissionSetLicenses task to add find_replace functionality.
    """
    pass


class AssignPermissionSetGroupsWithFindReplace(AssignPermissionSetsWithFindReplace, AssignPermissionSetGroups):
    """
    Extends the standard AssignPermissionSetGroups task to add find_replace functionality.
    """
    pass 