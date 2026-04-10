#!/bin/bash

echo "====================================="
echo "  VirtualBox 彻底卸载脚本"
echo "====================================="

# 1. 运行官方卸载工具
if [ -f "/Applications/VirtualBox.app/Contents/Resources/VirtualBox_Uninstall.tool" ]; then
    echo "→ 运行官方卸载脚本..."
    sudo /Applications/VirtualBox.app/Contents/Resources/VirtualBox_Uninstall.tool --unattended
else
    echo "→ VirtualBox 主程序已不存在，跳过官方卸载"
fi

# 2. 删除用户目录残留
echo "→ 删除用户配置与虚拟机文件..."
sudo rm -rf ~/Library/VirtualBox
rm -rf ~/Library/Preferences/org.virtualbox.*
rm -rf ~/Library/Saved Application State/org.virtualbox.*
rm -rf ~/VirtualBox\ VMs

# 3. 删除系统级残留
echo "→ 删除系统级文件..."
sudo rm -rf /Library/Application\ Support/VirtualBox
sudo rm -rf /Library/Preferences/org.virtualbox.*

# 4. 提示删除描述文件
echo ""
echo "====================================="
echo " 最后一步：手动删除配置描述文件"
echo " 系统设置 → 通用 → VPN与设备管理"
echo " 删除 Oracle VirtualBox VM 即可完成"
echo "====================================="
echo ""
echo "✅ 卸载完成！请重启 Mac。"