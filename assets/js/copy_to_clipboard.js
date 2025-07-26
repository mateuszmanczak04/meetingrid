export default {
	mounted() {
		this.el.addEventListener('click', (e) => {
			navigator.clipboard.writeText(window.location.href);
			this.pushEvent('share', {});
		});
	},
};
