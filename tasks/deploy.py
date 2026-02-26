import io
import re
import zipfile

from cumulusci.core.source_transforms.transforms import FindReplaceTransform
from cumulusci.tasks.salesforce.Deploy import Deploy as BaseDeployTask
from cumulusci.core.dependencies.utils import TaskContext


class FindReplaceWithFilename(FindReplaceTransform):
    """Extends the standard find_replace transform to also handle filenames."""

    def process(self, zf: zipfile.ZipFile, context: TaskContext) -> zipfile.ZipFile:
        # First do the normal find_replace on file contents
        zf = super().process(zf, context)

        # Then handle filenames
        zip_dest = zipfile.ZipFile(io.BytesIO(), "w", zipfile.ZIP_DEFLATED)
        for name in zf.namelist():
            content = zf.read(name)
            new_name = name

            # Apply each pattern to the filename
            for pattern in self.options.patterns:
                find = pattern.find
                if find and find in new_name:
                    replace = pattern.get_replace_string(context)
                    new_name = new_name.replace(find, replace)

            zip_dest.writestr(new_name, content)

        return zip_dest


def _strip_custom_index_from_package_xml(content: bytes) -> bytes:
    """Remove any <types>…<name>CustomIndex</name>…</types> block from package.xml."""
    text = content.decode("utf-8")
    # Remove the entire <types> block that contains <name>CustomIndex</name>
    text = re.sub(
        r"<types>\s*(?:<members>[^<]*</members>\s*)*<name>CustomIndex</name>\s*</types>\s*",
        "",
        text,
        flags=re.DOTALL,
    )
    return text.encode("utf-8")


class StripCustomIndexTransform:
    """Strips auto-generated CustomIndex entries from the MDAPI package ZIP.

    sfdx force:source:convert (v7.x) generates CustomIndex components from
    externalId=true fields and can produce stale object names after an object
    API-name rename (e.g. Request__c → WorkRequest__c).  CustomIndex records
    are managed automatically by Salesforce and do not need to be explicitly
    deployed, so stripping them is safe and avoids spurious deploy errors.
    """

    def process(self, zf: zipfile.ZipFile, context) -> zipfile.ZipFile:
        names = zf.namelist()
        has_custom_index = any("customindex" in n.lower() for n in names)
        if not has_custom_index:
            return zf

        zip_dest = zipfile.ZipFile(io.BytesIO(), "w", zipfile.ZIP_DEFLATED)
        for name in names:
            if "customindex" in name.lower():
                continue  # drop the CustomIndex file
            content = zf.read(name)
            if name.lower().endswith("package.xml"):
                content = _strip_custom_index_from_package_xml(content)
            zip_dest.writestr(name, content)
        return zip_dest


class Deploy(BaseDeployTask):
    """Deploy task that extends find_replace to handle filenames and strips
    auto-generated CustomIndex entries with stale object names."""

    def _init_options(self, kwargs):
        super()._init_options(kwargs)

        # Replace any find_replace transforms with our filename-aware version
        for i, transform in enumerate(self.transforms):
            if isinstance(transform, FindReplaceTransform):
                self.transforms[i] = FindReplaceWithFilename(transform.options)

        # Append CustomIndex stripping as the final transform so it runs after
        # all find_replace processing is complete
        self.transforms.append(StripCustomIndexTransform())
