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
    <script src="https://d3js.org/d3.v7.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Helvetica Neue', sans-serif; background: #f5f5f5; padding: 20px; line-height: 1.6; }
        .container { max-width: 1400px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); overflow: hidden; }
        header { background: linear-gradient(135deg, #063773 0%, #0a5aa8 100%); color: white; padding: 30px; }
        header h1 { font-size: 32px; margin-bottom: 10px; }
        
        /* Tabs */
        .tabs { display: flex; background: #f8f9fa; border-bottom: 2px solid #e0e0e0; }
        .tab { padding: 15px 30px; cursor: pointer; font-weight: 600; color: #666; border-bottom: 3px solid transparent; transition: all 0.2s; }
        .tab:hover { color: #063773; background: rgba(6, 55, 115, 0.05); }
        .tab.active { color: #063773; border-bottom-color: #063773; background: white; }
        
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
        .module-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.08); border-color: #063773; }
        .module-header { padding: 18px 24px; background: #fafafa; cursor: pointer; display: flex; justify-content: space-between; align-items: center; gap: 16px; transition: background 0.15s ease; }
        .module-header:hover { background: #f5f6fa; }
        .module-info { flex: 1; min-width: 0; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
        .module-name-row { font-size: 16px; font-weight: 600; color: #2d3748; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .module-version { color: #063773; }
        .owner-badge { display: inline-flex; align-items: center; padding: 4px 10px; background: linear-gradient(135deg, #063773 0%, #0a5aa8 100%); color: white; border-radius: 10px; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; box-shadow: 0 2px 4px rgba(6, 55, 115, 0.2); flex-shrink: 0; }
        .module-stats { display: flex; align-items: center; gap: 20px; flex-shrink: 0; }
        .module-stat { display: flex; flex-direction: column; align-items: flex-end; }
        .module-stat-label { font-size: 10px; color: #999; text-transform: uppercase; letter-spacing: 0.5px; }
        .module-stat-value { font-size: 14px; color: #063773; font-weight: 700; white-space: nowrap; }
        .module-size { font-size: 16px; color: #063773; font-weight: 700; white-space: nowrap; }
        .expand-icon { color: #063773; font-size: 12px; transition: transform 0.2s; }
        .expand-icon.open { transform: rotate(180deg); }
        
        .module-details { padding: 20px 24px; display: none; background: #fafafa; }
        .module-details.open { display: block; }
        
        .size-bars { margin-bottom: 30px; }
        .size-bar { margin-bottom: 15px; }
        .size-bar-label { display: flex; justify-content: space-between; margin-bottom: 5px; font-size: 14px; }
        .size-bar-label .name { color: #333; font-weight: 500; }
        .size-bar-label .value { color: #666; }
        .size-bar-fill { height: 8px; background: #e0e0e0; border-radius: 4px; overflow: hidden; }
        .size-bar-progress { height: 100%; background: linear-gradient(90deg, #063773 0%, #0a5aa8 100%); transition: width 0.3s; }
        
        .resources-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 30px; }
        .resource-card { background: white; padding: 15px; border-radius: 6px; border: 1px solid #e0e0e0; }
        .resource-type { font-size: 12px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 5px; }
        .resource-size { font-size: 18px; font-weight: bold; color: #333; }
        .resource-count { font-size: 12px; color: #999; }
        
        .files-section { margin-top: 30px; }
        .files-section h4 { font-size: 16px; margin-bottom: 15px; color: #333; display: flex; align-items: center; gap: 10px; }
        .files-section h4 .count-badge { background: #063773; color: white; padding: 2px 8px; border-radius: 10px; font-size: 12px; }
        .files-table { width: 100%; background: white; border-radius: 6px; overflow: hidden; border: 1px solid #e0e0e0; }
        .files-table-header { display: grid; grid-template-columns: 1fr auto; gap: 15px; padding: 12px 15px; background: #f8f9fa; font-weight: 600; font-size: 12px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #e0e0e0; }
        .file-row { display: grid; grid-template-columns: 1fr auto; gap: 15px; padding: 12px 15px; border-bottom: 1px solid #f0f0f0; transition: background 0.15s; align-items: center; }
        .file-row:last-child { border-bottom: none; }
        .file-row:hover { background: #f8f9fa; }
        .file-name { color: #2d3748; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Helvetica Neue', sans-serif; font-size: 13px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; text-align: left; }
        .file-size { color: #063773; font-weight: 600; font-size: 13px; text-align: right; white-space: nowrap; }
        
        .top-files { margin-top: 20px; }
        .top-files h4 { font-size: 16px; margin-bottom: 15px; color: #333; }
        .file-item { display: flex; justify-content: space-between; padding: 10px; background: white; margin-bottom: 5px; border-radius: 4px; font-size: 13px; border: 1px solid #e0e0e0; }
        .file-path { color: #666; flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Helvetica Neue', sans-serif; }
        .file-size-value { color: #333; font-weight: 500; margin-left: 15px; }
        
        .no-results { text-align: center; padding: 60px 20px; color: #999; font-size: 16px; }
        .no-data { padding: 15px; color: #999; font-style: italic; text-align: center; }
        
        /* D3 Chart Styles */
        .d3-tooltip {
            position: absolute;
            background: rgba(0, 0, 0, 0.9);
            color: white;
            padding: 12px 16px;
            border-radius: 6px;
            font-size: 13px;
            pointer-events: none;
            opacity: 0;
            transition: opacity 0.2s;
            z-index: 1000;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        }
        .d3-tooltip.visible { opacity: 1; }
        .d3-tooltip-owner { font-weight: bold; margin-bottom: 6px; font-size: 14px; }
        .d3-tooltip-row { margin: 3px 0; display: flex; align-items: center; gap: 8px; }
        .d3-tooltip-color { width: 12px; height: 12px; border-radius: 2px; display: inline-block; }
        .ownership-chart-container { position: relative; width: 100%; overflow-x: auto; }
        .axis text { font-size: 12px; fill: #666; }
        .axis line, .axis path { stroke: #e0e0e0; }
        .grid line { stroke: #e0e0e0; stroke-dasharray: 3,3; }
        .bar { cursor: pointer; transition: opacity 0.2s; }
        .bar:hover { opacity: 0.8; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1 id="headerTitle">📱 App Size Report</h1>
            <p id="headerSubtitle">Detailed analysis of app module sizes and resources</p>
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
        
        <!-- Ownership Tab -->
        <div id="ownership" class="tab-content">
            <div style="padding: 30px; background: white;">
                <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 30px;">
                    <div>
                        <h2 style="font-size: 20px; color: #333; margin-bottom: 10px;">Ownership overview</h2>
                        <p style="color: #666; font-size: 14px;">Shows how much of the overall app size is owned by each owner.</p>
                    </div>
                    <div style="min-width: 200px;">
                        <select id="ownershipSortSelect" style="width: 100%; padding: 10px 15px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; background: white; cursor: pointer;">
                            <option value="downloadSize">Sort by: Download Size</option>
                            <option value="installSize">Sort by: Install Size</option>
                        </select>
                    </div>
                </div>
                <div class="ownership-chart-container">
                    <div id="ownershipChart"></div>
                </div>
            </div>
            <div style="padding: 30px; background: #f8f9fa; border-top: 1px solid #e0e0e0;">
                <h2 style="font-size: 20px; color: #333; margin-bottom: 20px;">Components and files grouped by owner</h2>
                <select id="ownerDropdown" style="width: 100%; padding: 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; background: white; cursor: pointer;">
                    <option value="">Select an owner...</option>
                </select>
            </div>
            <div id="ownerDetailSection" style="display: none;">
                <div id="ownerDetailSummary" style="padding: 30px; background: white; border-top: 1px solid #e0e0e0; display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 30px;"></div>
                <div style="padding: 0 30px 30px 30px; background: white;">
                    <div class="modules-grid" id="ownerModulesGrid"></div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        const data = __DATA__;
        let currentTab = 'breakdown';
        let currentSort = 'downloadSize';
        
        // Update header with app info if available
        function updateHeader() {
            if (data.appInfo) {
                const appInfo = data.appInfo;
                let title = '📱 ';
                let subtitle = 'Detailed analysis of app module sizes and resources';
                
                if (appInfo.appName) {
                    title += appInfo.appName;
                } else {
                    title += 'App Size Report';
                }
                
                const subtitleParts = [];
                if (appInfo.version) {
                    subtitleParts.push('Version ' + appInfo.version);
                }
                if (appInfo.bundleIdentifier) {
                    subtitleParts.push(appInfo.bundleIdentifier);
                }
                
                if (subtitleParts.length > 0) {
                    subtitle = subtitleParts.join(' • ');
                }
                
                document.getElementById('headerTitle').textContent = title;
                document.getElementById('headerSubtitle').textContent = subtitle;
            }
        }
        
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
            let total = 0;
            
            // Add binary size
            total += module.binarySize || 0;
            
            // Add image file size
            total += module.imageFileSize || 0;
            
            // Add all resource sizes
            if (module.resources) {
                Object.values(module.resources).forEach(res => {
                    total += res.size || 0;
                });
            }
            
            return total;
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
                const topFiles = Object.entries(module.top || {}).sort((a, b) => b[1] - a[1]);
                const topFilesHTML = topFiles.length > 0 ? `
                    <div class="top-files">
                        <h4>Asset Files <span class="count-badge">${topFiles.length}</span></h4>
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
        
        // Ownership Tab Functions
        let ownershipData = [];
        let currentOwnershipSort = 'downloadSize';
        
        function prepareOwnershipData(sortBy = 'downloadSize') {
            // Group modules by owner property
            const modulesByOwner = {};
            let hasOwners = false;
            
            Object.entries(data.modules).forEach(([moduleName, module]) => {
                const owner = module.owner || 'others';
                if (module.owner) hasOwners = true;
                
                if (!modulesByOwner[owner]) {
                    modulesByOwner[owner] = {};
                }
                modulesByOwner[owner][moduleName] = module;
            });
            
            if (!hasOwners) {
                return [];
            }
            
            const ownerData = Object.entries(modulesByOwner).map(([ownerName, modules]) => {
                const moduleList = Object.values(modules);
                const totalBinarySize = moduleList.reduce((sum, m) => sum + (m.binarySize || 0), 0);
                const totalInstallSize = moduleList.reduce((sum, m) => sum + calculateModuleTotal(m), 0);
                const totalFiles = moduleList.reduce((sum, m) => sum + (m.files ? m.files.length : 0), 0);
                
                return {
                    name: ownerName,
                    modules: modules,
                    moduleCount: moduleList.length,
                    fileCount: totalFiles,
                    totalBinarySize: totalBinarySize,
                    totalInstallSize: totalInstallSize
                };
            });
            
            // Sort based on selected metric
            if (sortBy === 'installSize') {
                return ownerData.sort((a, b) => b.totalInstallSize - a.totalInstallSize);
            } else {
                return ownerData.sort((a, b) => b.totalBinarySize - a.totalBinarySize);
            }
        }
        
        function renderOwnershipChart() {
            const chartContainer = document.getElementById('ownershipChart');
            
            if (ownershipData.length === 0) {
                chartContainer.innerHTML = `
                    <div class="no-results">
                        <p>No ownership data available.</p>
                        <p style="font-size: 14px; margin-top: 10px; color: #666;">Run Caliper with the --ownership-file option to enable ownership tracking.</p>
                    </div>
                `;
                document.getElementById('ownerDropdown').disabled = true;
                return;
            }
            
            // Clear any existing chart
            chartContainer.innerHTML = '';
            
            // Chart dimensions
            const margin = { top: 20, right: 30, bottom: 120, left: 80 };
            const barWidth = 40;
            const barGap = 10;
            const groupGap = 30;
            const groupWidth = (barWidth * 2) + barGap;
            const width = ownershipData.length * (groupWidth + groupGap) + margin.left + margin.right;
            const height = 450;
            const chartHeight = height - margin.top - margin.bottom;
            
            // Calculate totals for percentages
            const totalBinarySize = ownershipData.reduce((sum, d) => sum + d.totalBinarySize, 0);
            const totalInstallSize = ownershipData.reduce((sum, d) => sum + d.totalInstallSize, 0);
            
            // Create tooltip
            const tooltip = d3.select('body').append('div')
                .attr('class', 'd3-tooltip');
            
            // Create SVG
            const svg = d3.select('#ownershipChart')
                .append('svg')
                .attr('width', width)
                .attr('height', height)
                .style('display', 'block')
                .style('margin', '0 auto');
            
            const g = svg.append('g')
                .attr('transform', `translate(${margin.left},${margin.top})`);
            
            // Scales
            const x = d3.scaleBand()
                .domain(ownershipData.map(d => d.name))
                .range([0, width - margin.left - margin.right])
                .padding(0.3);
            
            const maxSize = d3.max(ownershipData, d => Math.max(d.totalBinarySize, d.totalInstallSize));
            const y = d3.scaleLinear()
                .domain([0, maxSize])
                .nice()
                .range([chartHeight, 0]);
            
            // Grid lines
            g.append('g')
                .attr('class', 'grid')
                .call(d3.axisLeft(y)
                    .tickSize(-width + margin.left + margin.right)
                    .tickFormat('')
                );
            
            // Y axis with formatted bytes
            const yAxis = g.append('g')
                .attr('class', 'axis')
                .call(d3.axisLeft(y)
                    .tickFormat(d => formatBytes(d))
                    .ticks(5)
                );
            
            // X axis
            const xAxis = g.append('g')
                .attr('class', 'axis')
                .attr('transform', `translate(0,${chartHeight})`)
                .call(d3.axisBottom(x));
            
            // Rotate x-axis labels for better readability with long text
            xAxis.selectAll('text')
                .attr('transform', 'rotate(-55)')
                .style('text-anchor', 'end')
                .attr('dx', '-0.5em')
                .attr('dy', '0.5em')
                .style('font-size', '11px');
            
            // Create groups for each owner
            const ownerGroups = g.selectAll('.owner-group')
                .data(ownershipData)
                .enter()
                .append('g')
                .attr('class', 'owner-group')
                .attr('transform', d => `translate(${x(d.name)},0)`);
            
            // Download size bars (blue)
            ownerGroups.append('rect')
                .attr('class', 'bar download-bar')
                .attr('x', 0)
                .attr('width', barWidth)
                .attr('y', chartHeight)
                .attr('height', 0)
                .attr('fill', '#063773')
                .attr('rx', 3)
                .on('mouseover', function(event, d) {
                    d3.select(this).style('opacity', 0.7);
                    const percentage = totalBinarySize > 0 ? ((d.totalBinarySize / totalBinarySize) * 100).toFixed(1) : 0;
                    tooltip.html(`
                        <div class="d3-tooltip-owner">${escapeHtml(d.name)}</div>
                        <div class="d3-tooltip-row">
                            <span class="d3-tooltip-color" style="background: #063773;"></span>
                            <span>Download: ${formatBytes(d.totalBinarySize)} (${percentage}%)</span>
                        </div>
                        <div class="d3-tooltip-row">
                            <span>${d.moduleCount} module(s)</span>
                        </div>
                    `)
                    .classed('visible', true)
                    .style('left', (event.pageX + 10) + 'px')
                    .style('top', (event.pageY - 10) + 'px');
                })
                .on('mouseout', function() {
                    d3.select(this).style('opacity', 1);
                    tooltip.classed('visible', false);
                })
                .on('click', function(event, d) {
                    const index = ownershipData.indexOf(d);
                    document.getElementById('ownerDropdown').value = index;
                    renderOwnerDetails(index);
                    // Scroll to details
                    document.getElementById('ownerDetailSection').scrollIntoView({ behavior: 'smooth' });
                })
                .transition()
                .duration(800)
                .ease(d3.easeCubicOut)
                .attr('y', d => y(d.totalBinarySize))
                .attr('height', d => chartHeight - y(d.totalBinarySize));
            
            // Install size bars (green)
            ownerGroups.append('rect')
                .attr('class', 'bar install-bar')
                .attr('x', barWidth + barGap)
                .attr('width', barWidth)
                .attr('y', chartHeight)
                .attr('height', 0)
                .attr('fill', '#2ecc71')
                .attr('rx', 3)
                .on('mouseover', function(event, d) {
                    d3.select(this).style('opacity', 0.7);
                    const percentage = totalInstallSize > 0 ? ((d.totalInstallSize / totalInstallSize) * 100).toFixed(1) : 0;
                    tooltip.html(`
                        <div class="d3-tooltip-owner">${escapeHtml(d.name)}</div>
                        <div class="d3-tooltip-row">
                            <span class="d3-tooltip-color" style="background: #2ecc71;"></span>
                            <span>Install: ${formatBytes(d.totalInstallSize)} (${percentage}%)</span>
                        </div>
                        <div class="d3-tooltip-row">
                            <span>${d.moduleCount} module(s), ${d.fileCount} file(s)</span>
                        </div>
                    `)
                    .classed('visible', true)
                    .style('left', (event.pageX + 10) + 'px')
                    .style('top', (event.pageY - 10) + 'px');
                })
                .on('mouseout', function() {
                    d3.select(this).style('opacity', 1);
                    tooltip.classed('visible', false);
                })
                .on('click', function(event, d) {
                    const index = ownershipData.indexOf(d);
                    document.getElementById('ownerDropdown').value = index;
                    renderOwnerDetails(index);
                    // Scroll to details
                    document.getElementById('ownerDetailSection').scrollIntoView({ behavior: 'smooth' });
                })
                .transition()
                .duration(800)
                .ease(d3.easeCubicOut)
                .delay(100)
                .attr('y', d => y(d.totalInstallSize))
                .attr('height', d => chartHeight - y(d.totalInstallSize));
            
            // Legend
            const legend = svg.append('g')
                .attr('transform', `translate(${width / 2 - 100},${height - 25})`);
            
            // Download legend
            legend.append('rect')
                .attr('x', 0)
                .attr('y', 0)
                .attr('width', 20)
                .attr('height', 12)
                .attr('fill', '#063773')
                .attr('rx', 2);
            
            legend.append('text')
                .attr('x', 25)
                .attr('y', 10)
                .style('font-size', '12px')
                .style('fill', '#333')
                .text('Download size');
            
            // Install legend
            legend.append('rect')
                .attr('x', 130)
                .attr('y', 0)
                .attr('width', 20)
                .attr('height', 12)
                .attr('fill', '#2ecc71')
                .attr('rx', 2);
            
            legend.append('text')
                .attr('x', 155)
                .attr('y', 10)
                .style('font-size', '12px')
                .style('fill', '#333')
                .text('Install size');
        }
        
        function populateOwnerDropdown() {
            const dropdown = document.getElementById('ownerDropdown');
            
            if (ownershipData.length === 0) {
                dropdown.disabled = true;
                return;
            }
            
            dropdown.innerHTML = '<option value="">Select an owner...</option>';
            
            // Create array with owner and original index
            const ownerWithIndices = ownershipData.map((owner, index) => ({
                owner: owner,
                index: index
            }));
            
            // Separate "others" from regular owners
            const othersEntries = ownerWithIndices.filter(item => 
                item.owner.name.toLowerCase() === 'others' || 
                item.owner.name.toLowerCase() === 'other'
            );
            const regularEntries = ownerWithIndices.filter(item => 
                item.owner.name.toLowerCase() !== 'others' && 
                item.owner.name.toLowerCase() !== 'other'
            );
            
            // Sort regular owners alphabetically
            regularEntries.sort((a, b) => a.owner.name.localeCompare(b.owner.name));
            
            // Combine: regular owners first, then "others"
            const sortedEntries = [...regularEntries, ...othersEntries];
            
            // Populate dropdown
            sortedEntries.forEach(item => {
                const option = document.createElement('option');
                option.value = item.index;
                option.textContent = item.owner.name;
                dropdown.appendChild(option);
            });
        }
        
        function renderOwnerDetails(ownerIndex) {
            const detailSection = document.getElementById('ownerDetailSection');
            
            if (ownerIndex === '') {
                detailSection.style.display = 'none';
                return;
            }
            
            const owner = ownershipData[ownerIndex];
            detailSection.style.display = 'block';
            
            // Render summary
            const summaryDiv = document.getElementById('ownerDetailSummary');
            summaryDiv.innerHTML = `
                <div style="text-align: center;">
                    <div style="font-size: 36px; font-weight: bold; color: #333;">${owner.moduleCount}</div>
                    <div style="font-size: 14px; color: #666; margin-top: 5px;">Component(s)</div>
                </div>
                <div style="text-align: center;">
                    <div style="font-size: 36px; font-weight: bold; color: #333;">${owner.fileCount}</div>
                    <div style="font-size: 14px; color: #666; margin-top: 5px;">File(s)</div>
                </div>
                <div style="text-align: center;">
                    <div style="font-size: 36px; font-weight: bold; color: #063773;">${formatBytes(owner.totalBinarySize)}</div>
                    <div style="font-size: 14px; color: #666; margin-top: 5px;">Download size</div>
                </div>
                <div style="text-align: center;">
                    <div style="font-size: 36px; font-weight: bold; color: #2ecc71;">${formatBytes(owner.totalInstallSize)}</div>
                    <div style="font-size: 14px; color: #666; margin-top: 5px;">Install size</div>
                </div>
            `;
            
            // Render modules
            const modulesGrid = document.getElementById('ownerModulesGrid');
            const modules = Object.entries(owner.modules).sort((a, b) => {
                return (b[1].binarySize || 0) - (a[1].binarySize || 0);
            });
            
            const maxModuleSize = Math.max(...modules.map(([_, m]) => calculateModuleTotal(m)));
            
            modulesGrid.innerHTML = modules.map(([moduleName, module], index) => {
                const totalSize = calculateModuleTotal(module);
                const binaryPercent = maxModuleSize > 0 ? (module.binarySize || 0) / maxModuleSize * 100 : 0;
                const imagePercent = maxModuleSize > 0 ? (module.imageFileSize || 0) / maxModuleSize * 100 : 0;
                
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
                const topFiles = Object.entries(module.top || {}).sort((a, b) => b[1] - a[1]);
                const topFilesHTML = topFiles.length > 0 ? `
                    <div class="top-files">
                        <h4>Asset Files <span class="count-badge">${topFiles.length}</span></h4>
                        ${topFiles.map(([path, size]) => `<div class="file-item"><span class="file-path" title="${escapeHtml(path)}">${escapeHtml(path)}</span><span class="file-size-value">${formatBytes(size)}</span></div>`).join('')}
                    </div>
                ` : '';
                
                // Source files from LinkMap
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
                
                return `
                    <div class="module-card">
                        <div class="module-header" onclick="toggleOwnerModule(${ownerIndex}, ${index})">
                            <div class="module-info">
                                <div class="module-name-row">
                                    ${moduleName}
                                    ${module.version ? `<span class="module-version">:${module.version}</span>` : ''}
                                </div>
                            </div>
                            <div class="module-stats">
                                <div class="module-stat">
                                    <span class="module-stat-label">Download</span>
                                    <span class="module-size">${formatBytes(module.binarySize || 0)}</span>
                                </div>
                                <span class="expand-icon" id="owner-module-icon-${ownerIndex}-${index}">▼</span>
                            </div>
                        </div>
                        <div class="module-details" id="owner-module-${ownerIndex}-${index}">
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
        
        function toggleOwnerModule(ownerIndex, moduleIndex) {
            document.getElementById(`owner-module-${ownerIndex}-${moduleIndex}`).classList.toggle('open');
            document.getElementById(`owner-module-icon-${ownerIndex}-${moduleIndex}`).classList.toggle('open');
        }
        
        document.getElementById('ownerDropdown').addEventListener('change', (e) => {
            renderOwnerDetails(e.target.value);
        });
        
        document.getElementById('ownershipSortSelect').addEventListener('change', (e) => {
            currentOwnershipSort = e.target.value;
            ownershipData = prepareOwnershipData(currentOwnershipSort);
            renderOwnershipChart();
            populateOwnerDropdown();
            // Reset detail view
            document.getElementById('ownerDropdown').value = '';
            document.getElementById('ownerDetailSection').style.display = 'none';
        });
        
        updateHeader();
        renderSummary();
        renderModules();
        ownershipData = prepareOwnershipData(currentOwnershipSort);
        renderOwnershipChart();
        populateOwnerDropdown();
    </script>
</body>
</html>
"""
}

