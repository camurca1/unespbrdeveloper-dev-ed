import { LightningElement, api, track } from 'lwc';

export default class B2bCustomCombobox extends LightningElement {
    @api options = [{label: 'Option 1', value: 'Option 1'}, {label: 'Option 2', value: 'Option 2'}, {label: 'Option 3', value: 'Option 3'}];
    @track selectedLabel = '';
    @track selectedValue = '';
    @track isDropdownOpen = false;

    toggleDropdown() {
        this.isDropdownOpen = !this.isDropdownOpen;
    }

    selectOption(event) {
        const value = event.currentTarget.dataset.value;
        // console.log('value', value);
        const selectedOption = this.options.find(option => option.value === value);
        // console.log('selectedOption', selectedOption);
        this.selectedLabel = selectedOption.label;
        this.selectedValue = selectedOption.value;
        this.isDropdownOpen = false;
    }
}