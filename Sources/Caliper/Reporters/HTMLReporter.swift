import Foundation

/// Reporter for generating HTML output
struct HTMLReporter {
    
    /// Generate HTML report from JSON data
    func generate(jsonString: String, outputPath: String) throws {
        let html = htmlTemplate.replacingOccurrences(of: "__DATA__", with: jsonString)
        try html.write(toFile: outputPath, atomically: true, encoding: .utf8)
    }
    
    /// Determine HTML output path from JSON output path
    func determineOutputPath(from jsonPath: String) -> String {
        let url = URL(fileURLWithPath: jsonPath)
        
        if !url.pathExtension.isEmpty {
            return url.deletingPathExtension().appendingPathExtension("html").path
        } else {
            return jsonPath + ".html"
        }
    }
    
    // MARK: - HTML Template
    
    private let htmlTemplate = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>App Size Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Helvetica Neue', sans-serif; background: #f5f5f5; padding: 20px; line-height: 1.6; }
        .container { max-width: 1400px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); overflow: hidden; }
        header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; }
        header h1 { font-size: 32px; margin-bottom: 10px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; padding: 30px; background: #f8f9fa; border-bottom: 1px solid #e0e0e0; }
        .summary-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .summary-card h3 { font-size: 14px; color: #666; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.5px; }
        .summary-card .value { font-size: 28px; font-weight: bold; color: #333; }
        .controls { padding: 20px 30px; background: white; border-bottom: 1px solid #e0e0e0; display: flex; gap: 15px; flex-wrap: wrap; align-items: center; }
        .controls input { padding: 10px 15px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; flex: 1; min-width: 200px; }
        .controls select { padding: 10px 15px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; background: white; cursor: pointer; }
        .modules-grid { padding: 30px; }
        .module-card { background: white; border: 1px solid #e0e0e0; border-radius: 8px; margin-bottom: 20px; overflow: hidden; transition: box-shadow 0.2s; }
        .module-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
        .module-header { padding: 20px; background: #fafafa; border-bottom: 1px solid #e0e0e0; cursor: pointer; display: flex; justify-content: space-between; align-items: center; }
        .module-header:hover { background: #f0f0f0; }
        .module-title { font-size: 18px; font-weight: 600; color: #333; }
        .module-owner { font-size: 12px; color: #666; margin-top: 4px; }
        .module-size { font-size: 16px; color: #667eea; font-weight: bold; }
        .module-details { padding: 20px; display: none; }
        .module-details.open { display: block; }
        .size-bars { margin-bottom: 30px; }
        .size-bar { margin-bottom: 15px; }
        .size-bar-label { display: flex; justify-content: space-between; margin-bottom: 5px; font-size: 14px; }
        .size-bar-label .name { color: #333; font-weight: 500; }
        .size-bar-label .value { color: #666; }
        .size-bar-fill { height: 8px; background: #e0e0e0; border-radius: 4px; overflow: hidden; }
        .size-bar-progress { height: 100%; background: linear-gradient(90deg, #667eea 0%, #764ba2 100%); transition: width 0.3s; }
        .resources-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 30px; }
        .resource-card { background: #f8f9fa; padding: 15px; border-radius: 6px; }
        .resource-type { font-size: 12px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 5px; }
        .resource-size { font-size: 18px; font-weight: bold; color: #333; }
        .resource-count { font-size: 12px; color: #999; }
        .top-files { margin-top: 20px; }
        .top-files h4 { font-size: 16px; margin-bottom: 15px; color: #333; }
        .file-item { display: flex; justify-content: space-between; padding: 10px; background: #f8f9fa; margin-bottom: 5px; border-radius: 4px; font-size: 13px; }
        .file-path { color: #666; flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-family: 'Courier New', monospace; }
        .file-size { color: #333; font-weight: 500; margin-left: 15px; }
        .no-results { text-align: center; padding: 60px 20px; color: #999; font-size: 16px; }
        .expand-icon { transition: transform 0.2s; }
        .expand-icon.open { transform: rotate(180deg); }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📱 App Size Report</h1>
            <p>Detailed analysis of app module sizes and resources</p>
        </header>
        <div class="summary" id="summary"></div>
        <div class="controls">
            <input type="text" id="searchInput" placeholder="Search modules..." />
            <select id="sortSelect">
                <option value="size">Sort by: Total Size</option>
                <option value="binary">Sort by: Binary Size</option>
                <option value="name">Sort by: Name</option>
            </select>
            <select id="ownerFilter"><option value="">All Owners</option></select>
        </div>
        <div class="modules-grid" id="modulesGrid"></div>
    </div>
    <script>
        const data = __DATA__;
        function formatBytes(bytes) {
            if (bytes === 0) return '0 B';
            const k = 1024;
            const sizes = ['B', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }
        function calculateModuleTotal(module) { return module.proguard || 0; }
        function renderSummary() {
            const totalPackageSize = data.totalPackageSize || 0;
            const totalInstallSize = data.totalInstallSize || 0;
            const moduleCount = Object.keys(data.modules).length;
            const totalBinarySize = Object.values(data.modules).reduce((sum, m) => sum + (m.binarySize || 0), 0);
            document.getElementById('summary').innerHTML = `
                <div class="summary-card"><h3>Package Size (IPA)</h3><div class="value">${formatBytes(totalPackageSize)}</div></div>
                <div class="summary-card"><h3>Install Size</h3><div class="value">${formatBytes(totalInstallSize)}</div></div>
                <div class="summary-card"><h3>Total Binary Size</h3><div class="value">${formatBytes(totalBinarySize)}</div></div>
                <div class="summary-card"><h3>Module Count</h3><div class="value">${moduleCount}</div></div>
            `;
        }
        function getUniqueOwners() {
            const owners = new Set();
            Object.values(data.modules).forEach(module => { if (module.owner) owners.add(module.owner); });
            return Array.from(owners).sort();
        }
        function populateOwnerFilter() {
            const owners = getUniqueOwners();
            const select = document.getElementById('ownerFilter');
            owners.forEach(owner => {
                const option = document.createElement('option');
                option.value = owner;
                option.textContent = owner;
                select.appendChild(option);
            });
        }
        function renderModules(searchTerm = '', sortBy = 'size', ownerFilter = '') {
            let modules = Object.values(data.modules);
            if (searchTerm) modules = modules.filter(m => m.name.toLowerCase().includes(searchTerm.toLowerCase()));
            if (ownerFilter) modules = modules.filter(m => m.owner === ownerFilter);
            modules.sort((a, b) => {
                switch(sortBy) {
                    case 'size': return calculateModuleTotal(b) - calculateModuleTotal(a);
                    case 'binary': return (b.binarySize || 0) - (a.binarySize || 0);
                    case 'name': return a.name.localeCompare(b.name);
                    default: return 0;
                }
            });
            const grid = document.getElementById('modulesGrid');
            if (modules.length === 0) { grid.innerHTML = '<div class="no-results">No modules found</div>'; return; }
            const maxSize = Math.max(...modules.map(m => calculateModuleTotal(m)));
            grid.innerHTML = modules.map((module, index) => {
                const totalSize = calculateModuleTotal(module);
                const binaryPercent = maxSize > 0 ? (module.binarySize || 0) / maxSize * 100 : 0;
                const imagePercent = maxSize > 0 ? (module.imageFileSize || 0) / maxSize * 100 : 0;
                const resourcesHTML = Object.keys(module.resources || {}).length > 0 ? `
                    <h4 style="margin-top: 20px; margin-bottom: 15px; color: #333;">Resources</h4>
                    <div class="resources-grid">
                        ${Object.entries(module.resources).map(([type, res]) => `
                            <div class="resource-card">
                                <div class="resource-type">${type}</div>
                                <div class="resource-size">${formatBytes(res.size)}</div>
                                <div class="resource-count">${res.count} files</div>
                            </div>
                        `).join('')}
                    </div>
                ` : '';
                const topFiles = Object.entries(module.top || {}).sort((a, b) => b[1] - a[1]).slice(0, 10);
                const topFilesHTML = topFiles.length > 0 ? `
                    <div class="top-files">
                        <h4>Top 10 Largest Files</h4>
                        ${topFiles.map(([path, size]) => `
                            <div class="file-item">
                                <span class="file-path" title="${path}">${path}</span>
                                <span class="file-size">${formatBytes(size)}</span>
                            </div>
                        `).join('')}
                    </div>
                ` : '';
                return `
                    <div class="module-card">
                        <div class="module-header" onclick="toggleModule(${index})">
                            <div>
                                <div class="module-title">${module.name}</div>
                                ${module.owner ? `<div class="module-owner">Owner: ${module.owner}</div>` : ''}
                            </div>
                            <div style="text-align: right;">
                                <div class="module-size">${formatBytes(totalSize)}</div>
                                <span class="expand-icon" id="icon-${index}">▼</span>
                            </div>
                        </div>
                        <div class="module-details" id="module-${index}">
                            <div class="size-bars">
                                <div class="size-bar">
                                    <div class="size-bar-label"><span class="name">Binary Size</span><span class="value">${formatBytes(module.binarySize || 0)}</span></div>
                                    <div class="size-bar-fill"><div class="size-bar-progress" style="width: ${binaryPercent}%"></div></div>
                                </div>
                                <div class="size-bar">
                                    <div class="size-bar-label"><span class="name">Image Assets</span><span class="value">${formatBytes(module.imageFileSize || 0)}</span></div>
                                    <div class="size-bar-fill"><div class="size-bar-progress" style="width: ${imagePercent}%"></div></div>
                                </div>
                                <div class="size-bar">
                                    <div class="size-bar-label"><span class="name">Total (Uncompressed)</span><span class="value">${formatBytes(module.proguard || 0)}</span></div>
                                    <div class="size-bar-fill"><div class="size-bar-progress" style="width: 100%"></div></div>
                                </div>
                            </div>
                            ${resourcesHTML}
                            ${topFilesHTML}
                        </div>
                    </div>
                `;
            }).join('');
        }
        function toggleModule(index) {
            document.getElementById(`module-${index}`).classList.toggle('open');
            document.getElementById(`icon-${index}`).classList.toggle('open');
        }
        document.getElementById('searchInput').addEventListener('input', (e) => {
            renderModules(e.target.value, document.getElementById('sortSelect').value, document.getElementById('ownerFilter').value);
        });
        document.getElementById('sortSelect').addEventListener('change', (e) => {
            renderModules(document.getElementById('searchInput').value, e.target.value, document.getElementById('ownerFilter').value);
        });
        document.getElementById('ownerFilter').addEventListener('change', (e) => {
            renderModules(document.getElementById('searchInput').value, document.getElementById('sortSelect').value, e.target.value);
        });
        renderSummary();
        populateOwnerFilter();
        renderModules();
    </script>
</body>
</html>
"""
}

