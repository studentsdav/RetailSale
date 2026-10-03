def update_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    target = '    version: 110,'
    if target not in content:
        print(f'Target 110 not found in {path}')
        return

    if 'version: 111' in content:
        print(f'Version 111 already present in {path}')
        return

    m111 = """  },
  {
    version: 111,
    description: "Add modifier_details, modifier_objects, item_remark, and notes columns to sales_items table for modifier persistence",
    up: async (db: any) => {
      await db.query(`
        BEGIN;
        ALTER TABLE sales_items 
          ADD COLUMN IF NOT EXISTS modifier_details JSONB DEFAULT '[]'::jsonb,
          ADD COLUMN IF NOT EXISTS modifier_objects JSONB DEFAULT '[]'::jsonb,
          ADD COLUMN IF NOT EXISTS item_remark TEXT,
          ADD COLUMN IF NOT EXISTS notes TEXT;
        COMMIT;
      `);
    }
  }
];"""

    idx = content.rfind('  }\n];')
    if idx == -1:
        idx = content.rfind('  }\r\n];')
    if idx != -1:
        content = content[:idx] + m111 + content[idx + len('  }\n];'):]
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Successfully updated {path}')
    else:
        print(f'Could not find closing bracket in {path}')

for p in ['backend/utils/migrations.ts', 'backend/utils/migrations.js', 'backend/dist/utils/migrations.js']:
    import os
    if os.path.exists(p):
        update_file(p)
