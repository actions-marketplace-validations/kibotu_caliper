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
        
        /* Tabs */
        .tabs { display: flex; background: #f8f9fa; border-bottom: 2px solid #e0e0e0; }
        .tab { padding: 15px 30px; cursor: pointer; font-weight: 600; color: #666; border-bottom: 3px solid transparent; transition: all 0.2s; }
        .tab:hover { color: #667eea; background: rgba(102, 126, 234, 0.05); }
        .tab.active { color: #667eea; border-bottom-color: #667eea; background: white; }
        
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; padding: 30px; background: #f8f9fa; border-bottom: 1px solid #e0e0e0; }
        .summary-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .summary-card h3 { font-size: 14px; color: #666; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.5px; }
        .summary-card .value { font-size: 28px; font-weight: bold; color: #333; }
        .summary-card .label { font-size: 11px; color: #999; margin-top: 5px; }
        
        .controls { padding: 20px 30px; background: white; border-bottom: 1px solid #e0e0e0; display: flex; gap: 15px; flex-wrap: wrap; align-items: center; }
        .controls input { padding: 10px 15px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; flex: 1; min-width: 200px; }
        .controls select { padding: 10px 15px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; background: white; cursor: pointer; }
        
        .modules-grid { padding: 30px; }
        .module-card { background: white; border: 1px solid #e0e0e0; border-radius: 8px; margin-bottom: 16px; overflow: hidden; transition: all 0.2s ease; }
        .module-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.08); border-color: #667eea; }
        .module-header { padding: 18px 24px; background: #fafafa; cursor: pointer; display: flex; justify-content: space-between; align-items: center; gap: 16px; transition: background 0.15s ease; }
        .module-header:hover { background: #f5f6fa; }
        .module-info { flex: 1; min-width: 0; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
        .module-name-row { font-size: 16px; font-weight: 600; color: #2d3748; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .module-version { color: #667eea; }
        .owner-badge { display: inline-flex; align-items: center; padding: 4px 10px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border-radius: 10px; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; box-shadow: 0 2px 4px rgba(102, 126, 234, 0.2); flex-shrink: 0; }
        .module-stats { display: flex; align-items: center; gap: 20px; flex-shrink: 0; }
        .module-stat { display: flex; flex-direction: column; align-items: flex-end; }
        .module-stat-label { font-size: 10px; color: #999; text-transform: uppercase; letter-spacing: 0.5px; }
        .module-stat-value { font-size: 14px; color: #667eea; font-weight: 700; white-space: nowrap; }
        .module-size { font-size: 16px; color: #667eea; font-weight: 700; white-space: nowrap; }
        .expand-icon { color: #667eea; font-size: 12px; transition: transform 0.2s; }
        .expand-icon.open { transform: rotate(180deg); }
        
        .module-details { padding: 20px 24px; display: none; background: #fafafa; }
        .module-details.open { display: block; }
        
        .size-bars { margin-bottom: 30px; }
        .size-bar { margin-bottom: 15px; }
        .size-bar-label { display: flex; justify-content: space-between; margin-bottom: 5px; font-size: 14px; }
        .size-bar-label .name { color: #333; font-weight: 500; }
        .size-bar-label .value { color: #666; }
        .size-bar-fill { height: 8px; background: #e0e0e0; border-radius: 4px; overflow: hidden; }
        .size-bar-progress { height: 100%; background: linear-gradient(90deg, #667eea 0%, #764ba2 100%); transition: width 0.3s; }
        
        .resources-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 30px; }
        .resource-card { background: white; padding: 15px; border-radius: 6px; border: 1px solid #e0e0e0; }
        .resource-type { font-size: 12px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 5px; }
        .resource-size { font-size: 18px; font-weight: bold; color: #333; }
        .resource-count { font-size: 12px; color: #999; }
        
        .files-section { margin-top: 30px; }
        .files-section h4 { font-size: 16px; margin-bottom: 15px; color: #333; display: flex; align-items: center; gap: 10px; }
        .files-section h4 .count-badge { background: #667eea; color: white; padding: 2px 8px; border-radius: 10px; font-size: 12px; }
        .files-table { width: 100%; background: white; border-radius: 6px; overflow: hidden; border: 1px solid #e0e0e0; }
        .files-table-header { display: grid; grid-template-columns: 1fr auto; gap: 15px; padding: 12px 15px; background: #f8f9fa; font-weight: 600; font-size: 12px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #e0e0e0; }
        .file-row { display: grid; grid-template-columns: 1fr auto; gap: 15px; padding: 12px 15px; border-bottom: 1px solid #f0f0f0; transition: background 0.15s; align-items: center; }
        .file-row:last-child { border-bottom: none; }
        .file-row:hover { background: #f8f9fa; }
        .file-name { color: #2d3748; font-family: 'Courier New', monospace; font-size: 13px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; text-align: left; }
        .file-size { color: #667eea; font-weight: 600; font-size: 13px; text-align: right; white-space: nowrap; }
        
        .top-files { margin-top: 20px; }
        .top-files h4 { font-size: 16px; margin-bottom: 15px; color: #333; }
        .file-item { display: flex; justify-content: space-between; padding: 10px; background: white; margin-bottom: 5px; border-radius: 4px; font-size: 13px; border: 1px solid #e0e0e0; }
        .file-path { color: #666; flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-family: 'Courier New', monospace; }
        .file-size-value { color: #333; font-weight: 500; margin-left: 15px; }
        
        .no-results { text-align: center; padding: 60px 20px; color: #999; font-size: 16px; }
        .no-data { padding: 15px; color: #999; font-style: italic; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📱 App Size Report</h1>
            <p>Detailed analysis of app module sizes and resources</p>
        </header>
        
        <div class="tabs">
            <div class="tab active" onclick="switchTab('breakdown')">Breakdown</div>
            <div class="tab" onclick="switchTab('insights')">Insights</div>
            <div class="tab" onclick="switchTab('ownership')">Ownership</div>
        </div>
        
        <!-- Breakdown Tab -->
        <div id="breakdown" class="tab-content active">
            <div class="summary" id="summary"></div>
            <div class="controls">
                <input type="text" id="searchInput" placeholder="Search modules..." />
                <select id="sortSelect">
                    <option value="downloadSize">Sort by: Download Size</option>
                    <option value="installSize">Sort by: Install Size</option>
                    <option value="name">Sort by: Name</option>
                </select>
            </div>
            <div class="modules-grid" id="modulesGrid"></div>
        </div>
        
        <!-- Insights Tab (Placeholder) -->
        <div id="insights" class="tab-content">
            <div class="summary">
                <div class="summary-card">
                    <h3>Coming Soon</h3>
                    <p>Insights and analytics will be available in a future update.</p>
                </div>
            </div>
        </div>
        
        <!-- Ownership Tab (Placeholder) -->
        <div id="ownership" class="tab-content">
            <div class="summary">
                <div class="summary-card">
                    <h3>Coming Soon</h3>
                    <p>Ownership breakdown will be available in a future update.</p>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        const data = __DATA__;
        let currentTab = 'breakdown';
        let currentSort = 'downloadSize';
        
        function switchTab(tabName) {
            currentTab = tabName;
            document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
            event.target.classList.add('active');
            document.getElementById(tabName).classList.add('active');
        }
        
        function formatBytes(bytes) {
            if (bytes === 0) return '0 B';
            const k = 1024;
            const sizes = ['B', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }
        
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
        
        function calculateModuleTotal(module) {
            return module.proguard || 0;
        }
        
        function renderSummary() {
            const totalPackageSize = data.totalPackageSize || 0;
            const totalInstallSize = data.totalInstallSize || 0;
            const moduleCount = Object.keys(data.modules).length;
            const totalBinarySize = Object.values(data.modules).reduce((sum, m) => sum + (m.binarySize || 0), 0);
            
            document.getElementById('summary').innerHTML = `
                <div class="summary-card">
                    <h3>Download Size</h3>
                    <div class="value">${formatBytes(totalPackageSize)}</div>
                    <div class="label">Compressed IPA</div>
                </div>
                <div class="summary-card">
                    <h3>Install Size</h3>
                    <div class="value">${formatBytes(totalInstallSize)}</div>
                    <div class="label">Uncompressed</div>
                </div>
                <div class="summary-card">
                    <h3>Binary Size</h3>
                    <div class="value">${formatBytes(totalBinarySize)}</div>
                    <div class="label">Executable Code</div>
                </div>
                <div class="summary-card">
                    <h3>Modules</h3>
                    <div class="value">${moduleCount}</div>
                    <div class="label">Total Count</div>
                </div>
            `;
        }
        
        function renderModules(searchTerm = '', sortBy = 'downloadSize') {
            currentSort = sortBy;
            let modules = Object.values(data.modules);
            
            if (searchTerm) {
                modules = modules.filter(m => m.name.toLowerCase().includes(searchTerm.toLowerCase()));
            }
            
            modules.sort((a, b) => {
                switch(sortBy) {
                    case 'downloadSize':
                        // Use binarySize as proxy for download size since it's the main contributor
                        return (b.binarySize || 0) - (a.binarySize || 0);
                    case 'installSize':
                        return calculateModuleTotal(b) - calculateModuleTotal(a);
                    case 'name':
                        return a.name.localeCompare(b.name);
                    default:
                        return 0;
                }
            });
            
            const grid = document.getElementById('modulesGrid');
            if (modules.length === 0) {
                grid.innerHTML = '<div class="no-results">No modules found</div>';
                return;
            }
            
            const maxSize = Math.max(...modules.map(m => calculateModuleTotal(m)));
            
            grid.innerHTML = modules.map((module, index) => {
                const totalSize = calculateModuleTotal(module);
                const binaryPercent = maxSize > 0 ? (module.binarySize || 0) / maxSize * 100 : 0;
                const imagePercent = maxSize > 0 ? (module.imageFileSize || 0) / maxSize * 100 : 0;
                
                // Resources section
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
                
                // Top files from asset catalog
                const topFiles = Object.entries(module.top || {}).sort((a, b) => b[1] - a[1]).slice(0, 10);
                const topFilesHTML = topFiles.length > 0 ? `
                    <div class="top-files">
                        <h4>Top 10 Largest Asset Files</h4>
                        ${topFiles.map(([path, size]) => `<div class="file-item"><span class="file-path" title="${escapeHtml(path)}">${escapeHtml(path)}</span><span class="file-size-value">${formatBytes(size)}</span></div>`).join('')}
                    </div>
                ` : '';
                
                // Source files from LinkMap (show ALL files)
                const sourceFiles = module.files || [];
                const filesHTML = sourceFiles.length > 0 ? `
                    <div class="files-section">
                        <h4>
                            Source Files
                            <span class="count-badge">${sourceFiles.length}</span>
                        </h4>
                        <div class="files-table">
                            <div class="files-table-header">
                                <div>File Name</div>
                                <div>Size</div>
                            </div>
                            ${sourceFiles.map(file => `<div class="file-row"><div class="file-name" title="${escapeHtml(file.fileName)}">${escapeHtml(file.fileName)}</div><div class="file-size">${formatBytes(file.size)}</div></div>`).join('')}
                        </div>
                    </div>
                ` : '';
                
                // Determine which size to display based on current sort
                const displaySize = currentSort === 'installSize' ? totalSize : (module.binarySize || 0);
                const displayLabel = currentSort === 'installSize' ? 'Install' : 'Download';
                
                return `
                    <div class="module-card">
                        <div class="module-header" onclick="toggleModule(${index})">
                            <div class="module-info">
                                <div class="module-name-row">
                                    ${module.name}
                                    ${module.version ? `<span class="module-version">:${module.version}</span>` : ''}
                                </div>
                                ${module.owner ? `<span class="owner-badge">${module.owner}</span>` : ''}
                            </div>
                            <div class="module-stats">
                                <div class="module-stat">
                                    <span class="module-stat-label">${displayLabel}</span>
                                    <span class="module-size">${formatBytes(displaySize)}</span>
                                </div>
                                <span class="expand-icon" id="icon-${index}">▼</span>
                            </div>
                        </div>
                        <div class="module-details" id="module-${index}">
                            <div class="size-bars">
                                <div class="size-bar">
                                    <div class="size-bar-label">
                                        <span class="name">Binary Size</span>
                                        <span class="value">${formatBytes(module.binarySize || 0)}</span>
                                    </div>
                                    <div class="size-bar-fill">
                                        <div class="size-bar-progress" style="width: ${binaryPercent}%"></div>
                                    </div>
                                </div>
                                <div class="size-bar">
                                    <div class="size-bar-label">
                                        <span class="name">Image Assets</span>
                                        <span class="value">${formatBytes(module.imageFileSize || 0)}</span>
                                    </div>
                                    <div class="size-bar-fill">
                                        <div class="size-bar-progress" style="width: ${imagePercent}%"></div>
                                    </div>
                                </div>
                                <div class="size-bar">
                                    <div class="size-bar-label">
                                        <span class="name">Total (Install Size)</span>
                                        <span class="value">${formatBytes(totalSize)}</span>
                                    </div>
                                    <div class="size-bar-fill">
                                        <div class="size-bar-progress" style="width: 100%"></div>
                                    </div>
                                </div>
                            </div>
                            ${resourcesHTML}
                            ${topFilesHTML}
                            ${filesHTML}
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
            renderModules(e.target.value, document.getElementById('sortSelect').value);
        });
        
        document.getElementById('sortSelect').addEventListener('change', (e) => {
            renderModules(document.getElementById('searchInput').value, e.target.value);
        });
        
        renderSummary();
        renderModules();
    </script>
</body>
</html>
"""
}

