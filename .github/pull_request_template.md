## 变更摘要
- 说明这次只解决了什么问题

## 验证
- [ ] `python3 scripts/validate_feature_list.py feature_list.json`
- [ ] `python3 scripts/doc_gardening.py --check`
- [ ] `./scripts/check_architecture.sh`
- [ ] `xcodebuild -project SecretSync.xcodeproj -scheme SecretSync -destination "platform=macOS" test`

## Harness 约束
- 本 PR 是否只推进了一个最高优先级未通过功能？
- 是否更新了 `feature_list.json`？
- 是否追加写入了 `project-progress.txt`？
