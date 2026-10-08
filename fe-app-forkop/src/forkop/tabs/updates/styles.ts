// language=CSS
import { FORKOP_UCI_PACKAGE as FORKOP_CBI_PREFIX } from '../../../constants';

export const styles = `
#cbi-${FORKOP_CBI_PREFIX}-updates-_mount_node > div {
    width: 100%;
}

#cbi-${FORKOP_CBI_PREFIX}-updates > h3 {
    display: none;
}

.fkp_updates-page {
    width: 100%;
}

.fkp_updates-page__components {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    width: 100%;
    flex-wrap: wrap;
}

.fkp_updates-page__components-column {
    display: flex;
    flex: 1 1 auto;
    flex-direction: column;
    gap: 10px;
    min-width: max-content;
}

@media (max-width: 760px) {
    .fkp_updates-page__components {
        flex-direction: column;
    }

    .fkp_updates-page__components-column {
        width: 100%;
        min-width: 0;
    }
}

.fkp_updates-page__component {
    border: 2px var(--background-color-low, lightgray) solid;
    border-radius: 4px;
    padding: 10px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    min-width: max-content;
}

.fkp_updates-page__component__header {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
    border-bottom: 1px var(--background-color-low, lightgray) solid;
    padding-bottom: 8px;
    margin-bottom: 2px;
}

.fkp_updates-page__component__title {
    color: var(--text-color-high);
    font-size: 16px;
    font-weight: bold;
    line-height: 1.2;
}

.fkp_updates-page__component__header-version {
    color: var(--text-color-medium, #888);
    font-size: 13px;
    font-weight: normal;
}

.fkp_updates-page__component__details {
    display: flex;
    flex-direction: column;
    gap: 6px;
}

.fkp_updates-page__component__info-row {
    display: flex;
    justify-content: flex-start;
    align-items: center;
    min-height: 24px;
    gap: 8px;
    white-space: nowrap;
}

.fkp_updates-page__component__info-label {
    color: var(--text-color-medium, #888);
    font-size: 12px;
}

.fkp_updates-page__component__info-value {
    color: var(--text-color-high, #000);
    font-weight: 500;
    font-size: 13px;
    text-align: left;
    display: flex;
    align-items: center;
    gap: 6px;
    min-width: 0;
    overflow-wrap: anywhere;
}

.fkp_updates-page__component__info-value--latest {
    flex-wrap: wrap;
    justify-content: flex-start;
}

.fkp_updates-page__component__release-version-link {
    color: var(--link-color, #3498db) !important;
    text-decoration: underline;
    font-weight: bold;
}

.fkp_updates-page__component__release-version-link:hover {
    color: var(--link-color-dark, #2980b9) !important;
}

.fkp_updates-page__component__actions {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-top: auto;
}

.fkp_updates-page__component__actions--with-details {
    border-top: 1px var(--background-color-low, lightgray) solid;
    padding-top: 10px;
}

.fkp_updates-page__component__actions-main {
    display: flex;
    justify-content: flex-start;
    align-items: center;
    flex-wrap: nowrap;
    gap: 6px;
}

.fkp_updates-page__component__variants {
    display: flex;
    flex-direction: column;
    gap: 6px;
    margin-top: 4px;
}

.fkp_updates-page__component__variants-title {
    font-size: 11px;
    font-weight: bold;
    color: var(--text-color-medium, gray);
}

.fkp_updates-page__component__variants-buttons {
    display: flex;
    flex-wrap: nowrap;
    gap: 6px;
}

.fkp_updates-page__component__versions {
    margin-top: 6px;
}

.fkp-version-picker {
    margin-top: 8px;
    padding: 8px;
    border: 1px solid var(--border-color-low, #dee2e6);
    border-radius: 4px;
    background: var(--background-color-low, #f8f9fa);
}

.fkp-version-picker__loading,
.fkp-version-picker__error {
    padding: 6px 0;
    font-size: 12px;
    color: var(--text-color-medium, #6c757d);
}

.fkp-version-picker__error {
    color: var(--color-red-base, #e74c3c);
}

.fkp-version-picker__list {
    display: flex;
    flex-direction: column;
    gap: 6px;
}

.fkp-version-picker__item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 0;
    border-bottom: 1px solid var(--border-color-low, #e9ecef);
}

.fkp-version-picker__item:last-child {
    border-bottom: none;
}

.fkp-version-picker__tag {
    font-weight: bold;
    font-size: 13px;
    color: var(--text-color-high, inherit);
}

.fkp-version-picker__date {
    font-size: 11px;
    color: var(--text-color-medium, #6c757d);
}

.fkp-version-picker__prerelease {
    font-size: 10px;
    color: var(--color-yellow-base, #f39c12);
    border: 1px solid var(--color-yellow-base, #f39c12);
    border-radius: 3px;
    padding: 1px 4px;
}
`;
