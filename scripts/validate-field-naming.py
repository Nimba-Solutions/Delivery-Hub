#!/usr/bin/env python3
"""
Delivery Hub field naming convention validator.

Walks every force-app/main/default/objects/**/fields/*.field-meta.xml file and
verifies the API name suffix matches the field type, per docs/FIELD_NAMING.md.

Exits 0 on success, 1 on any violation. Designed to run in CI on every PR.

Skip mechanism: a field can opt out by including the literal string
`naming-validator: skip` anywhere in its XML. Use only for unfixable cases.
"""
import os
import re
import sys
import glob

# Type → required suffix (or set of accepted suffixes for the bare-name types)
SUFFIX_FOR_TYPE = {
    'Text':                 ['Txt'],
    'TextArea':             ['Txt'],
    'LongTextArea':         ['Txt'],
    'Html':                 ['Txt'],
    'EncryptedText':        ['Txt'],
    'Picklist':             ['Pk'],
    'MultiselectPicklist':  ['Pk'],
    'Number':               ['Number'],
    'Currency':             ['Currency'],
    'Date':                 ['Date'],
    'DateTime':             ['DateTime'],
    'Time':                 ['Time'],
    'Lookup':               ['Lookup'],
    'MasterDetail':         ['Lookup'],
    'Hierarchy':            ['Lookup'],
    'MetadataRelationship': ['Mdt'],
    'Percent':              ['Pct'],
    'Summary':              ['Sum'],
    'Email':                ['Email'],         # bare — field name carries it
    'Url':                  ['Url'],
    'Phone':                ['Phone'],
    'Location':             ['Geo'],
    'Checkbox':             ['Bool'],          # FORBIDDEN to add new ones
}

# Valid return-type suffixes for Formula fields
FORMULA_RETURN_SUFFIX = {
    'Text':     'Txt',
    'Number':   'Number',
    'Currency': 'Currency',
    'Date':     'Date',
    'DateTime': 'DateTime',
    'Time':     'Time',
    'Checkbox': 'Bool',
    'Percent':  'Pct',
}

SKIP_MARKER = 'naming-validator: skip'


def parse_field(path):
    """Return (name, type, is_formula, content).

    For Salesforce formula fields, <type> holds the formula's *return type*
    (e.g. <type>Number</type> + <formula>EstimatedHoursNumber__c - …</formula>).
    There is no separate <returnType> element in field metadata XML.
    """
    with open(path, 'r', encoding='utf-8') as fh:
        content = fh.read()
    name = os.path.basename(path).replace('.field-meta.xml', '')
    type_match = re.search(r'<type>([^<]+)</type>', content)
    field_type = type_match.group(1) if type_match else None
    is_formula = bool(re.search(r'<formula>', content))
    return name, field_type, is_formula, content


def validate_field(path):
    """Return list of violation messages for this field, empty if clean."""
    name, ftype, is_formula, content = parse_field(path)
    if SKIP_MARKER in content:
        return []
    base = name.replace('__c', '')
    rel = path.replace('\\', '/')

    if ftype is None:
        return [f'{rel}: missing <type>']

    # Forbid new Checkbox fields outright (whether formula or not)
    if ftype == 'Checkbox':
        return [
            f'{rel}: Checkbox is forbidden — convert to DateTime '
            f'(null = off, populated = on since X). See docs/FIELD_NAMING.md.'
        ]

    if is_formula:
        # For formula fields, <type> IS the return type
        expected = FORMULA_RETURN_SUFFIX.get(ftype)
        if not expected:
            return [f'{rel}: Formula return type={ftype} has no defined suffix']
        if not base.endswith(expected):
            return [
                f'{rel}: Formula returns {ftype}, expected suffix={expected}, '
                f'got name={name}'
            ]
        return []

    accepted_suffixes = SUFFIX_FOR_TYPE.get(ftype)
    if not accepted_suffixes:
        return [f'{rel}: type={ftype} has no defined suffix in validator']

    for sfx in accepted_suffixes:
        if base.endswith(sfx):
            return []

    return [
        f'{rel}: type={ftype}, expected suffix in {accepted_suffixes}, got name={name}'
    ]


def main():
    pattern = 'force-app/main/default/objects/**/fields/*.field-meta.xml'
    files = sorted(glob.glob(pattern, recursive=True))
    if not files:
        print(f'No field metadata files found at {pattern}', file=sys.stderr)
        return 1

    violations = []
    for f in files:
        violations.extend(validate_field(f))

    if violations:
        print(f'FIELD NAMING VALIDATION FAILED — {len(violations)} violation(s):', file=sys.stderr)
        print(file=sys.stderr)
        for v in violations:
            print(f'  {v}', file=sys.stderr)
        print(file=sys.stderr)
        print('See docs/FIELD_NAMING.md for the canonical suffix table.', file=sys.stderr)
        return 1

    print(f'OK — {len(files)} field(s) validated, zero violations.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
